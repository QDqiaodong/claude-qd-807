package com.vehicle.check.service;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.temporal.ChronoUnit;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.stream.Collectors;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Isolation;
import org.springframework.transaction.annotation.Transactional;

import com.vehicle.check.common.BizException;
import com.vehicle.check.common.StationDict;
import com.vehicle.check.domain.Device;
import com.vehicle.check.domain.Line;
import com.vehicle.check.domain.Report;
import com.vehicle.check.domain.Station;
import com.vehicle.check.domain.Task;
import com.vehicle.check.domain.TaskStationRecord;
import com.vehicle.check.domain.TransferRecord;
import com.vehicle.check.domain.Vehicle;
import com.vehicle.check.dto.AffectedTaskVO;
import com.vehicle.check.dto.CandidateLineVO;
import com.vehicle.check.dto.StationQueueDTO;
import com.vehicle.check.dto.TransferRecordVO;
import com.vehicle.check.dto.TransferRequest;
import com.vehicle.check.dto.TransferResultVO;
import com.vehicle.check.repository.DeviceRepository;
import com.vehicle.check.repository.DriverRepository;
import com.vehicle.check.repository.LineRepository;
import com.vehicle.check.repository.ReportRepository;
import com.vehicle.check.repository.StationRepository;
import com.vehicle.check.repository.TaskRepository;
import com.vehicle.check.repository.TaskStationRecordRepository;
import com.vehicle.check.repository.TransferRecordRepository;
import com.vehicle.check.repository.VehicleRepository;

/**
 * 在检车辆跨线恢复处置台。
 * <p>
 * 硬条件（不满足即排除，并逐条展示原因）：检测线运行中、剩余工位顺序一致、
 * 车型承接能力、标定设备全部有效、目标工位可接入（空闲且下游无故障）。
 * 软条件：目标工位排队与剩余工位负载，只在可用线之间排序，不能凌驾硬条件。
 * <p>
 * 确认转线走「CAS 占位目标工位 → CAS 迁移任务 → 释放旧工位 → 写处置记录」
 * 单事务四步，任一步失败整体回滚，杜绝旧线仍占位而新线已接车的半迁移。
 */
@Service
public class TransferService {

    private final TaskRepository taskRepository;
    private final TaskStationRecordRepository recordRepository;
    private final TransferRecordRepository transferRepository;
    private final VehicleRepository vehicleRepository;
    private final LineRepository lineRepository;
    private final StationRepository stationRepository;
    private final DeviceRepository deviceRepository;
    private final ReportRepository reportRepository;
    private final DriverRepository driverRepository;
    private final TaskFlowService taskFlowService;

    public TransferService(TaskRepository taskRepository, TaskStationRecordRepository recordRepository,
                           TransferRecordRepository transferRepository, VehicleRepository vehicleRepository,
                           LineRepository lineRepository, StationRepository stationRepository,
                           DeviceRepository deviceRepository, ReportRepository reportRepository,
                           DriverRepository driverRepository, TaskFlowService taskFlowService) {
        this.taskRepository = taskRepository;
        this.recordRepository = recordRepository;
        this.transferRepository = transferRepository;
        this.vehicleRepository = vehicleRepository;
        this.lineRepository = lineRepository;
        this.stationRepository = stationRepository;
        this.deviceRepository = deviceRepository;
        this.reportRepository = reportRepository;
        this.driverRepository = driverRepository;
        this.taskFlowService = taskFlowService;
    }

    /**
     * 受影响车辆：在检 / 复检任务，当前工位处于故障状态。
     * 车辆保持待处置并保留故障前进度，故障解除后可回原线继续。
     */
    public List<AffectedTaskVO> affectedVehicles() {
        List<Station> faultStations = stationRepository.findByStatus("FAULT");
        if (faultStations.isEmpty()) {
            return List.of();
        }
        List<Long> faultIds = faultStations.stream().map(Station::getId).toList();
        Map<Long, Station> faultMap = faultStations.stream()
                .collect(Collectors.toMap(Station::getId, s -> s, (a, b) -> a));
        List<Task> tasks = taskRepository.findByStatusInAndCurrentStationIdInOrderByIdAsc(
                List.of("CHECKING", "RETEST"), faultIds);

        List<AffectedTaskVO> result = new ArrayList<>();
        for (Task task : tasks) {
            Vehicle vehicle = vehicleRepository.findById(task.getVehicleId()).orElse(null);
            Line line = lineRepository.findById(task.getLineId()).orElse(null);
            Station fault = faultMap.get(task.getCurrentStationId());
            List<TaskStationRecord> records = recordRepository.findByTaskIdOrderBySeqNoAsc(task.getId());

            AffectedTaskVO vo = new AffectedTaskVO();
            vo.setTaskId(task.getId());
            vo.setTaskNo(task.getTaskNo());
            vo.setPlateNo(vehicle == null ? "" : vehicle.getPlateNo());
            vo.setOwnerName(vehicle == null ? "" : vehicle.getOwnerName());
            vo.setVehicleType(vehicle == null ? "" : vehicle.getVehicleType());
            vo.setVehicleTypeName(vehicle == null ? "" : StationDict.vehicleTypeName(vehicle.getVehicleType()));
            vo.setLineId(task.getLineId());
            vo.setLineNo(line == null ? "" : line.getLineNo());
            vo.setLineName(line == null ? "" : line.getLineName());
            vo.setFaultStationId(task.getCurrentStationId());
            vo.setFaultStationType(fault == null ? "" : fault.getStationType());
            vo.setFaultStationName(fault == null ? "" : fault.getStationName());
            vo.setCurrentSeqNo(task.getCurrentSeqNo());
            vo.setStatus(task.getStatus());
            vo.setStatusName(StationDict.taskStatusName(task.getStatus()));
            vo.setRetestTimes(task.getRetestTimes());
            vo.setDriverName(task.getDriverId() == null ? null
                    : driverRepository.findById(task.getDriverId()).map(d -> d.getDriverName()).orElse(null));

            Set<String> done = new LinkedHashSet<>();
            long failCount = 0;
            for (TaskStationRecord record : records) {
                done.add(StationDict.stationName(record.getStationType()));
                if ("FAIL".equals(record.getResult())) {
                    failCount++;
                }
            }
            vo.setDoneStations(new ArrayList<>(done));
            vo.setRemainingStations(remainingTypes(task.getCurrentSeqNo()).stream()
                    .map(StationDict::stationName).toList());
            vo.setFailRecordCount(failCount);
            if ("RETEST".equals(task.getStatus()) && vehicle != null) {
                vo.setOriginReportNo(reportRepository
                        .findFirstByPlateNoAndConclusionOrderByIdDesc(vehicle.getPlateNo(), "FAIL")
                        .map(Report::getReportNo).orElse(null));
            }
            result.add(vo);
        }
        return result;
    }

    public long affectedCount() {
        List<Station> faultStations = stationRepository.findByStatus("FAULT");
        if (faultStations.isEmpty()) {
            return 0;
        }
        return taskRepository.findByStatusInAndCurrentStationIdInOrderByIdAsc(
                List.of("CHECKING", "RETEST"),
                faultStations.stream().map(Station::getId).toList()).size();
    }

    /**
     * 候选检测线评估：全部线逐条给出推荐 / 排除原因，可用线按负载升序，负载最低者标记推荐。
     */
    public List<CandidateLineVO> candidates(Long taskId) {
        Task task = taskRepository.findById(taskId)
                .orElseThrow(() -> new BizException("检测任务不存在：id=" + taskId));
        Vehicle vehicle = vehicleRepository.findById(task.getVehicleId())
                .orElseThrow(() -> new BizException("任务 " + task.getTaskNo() + " 关联车辆已丢失"));
        List<String> remaining = remainingTypes(task.getCurrentSeqNo());
        Map<Long, Long> queueMap = queueMap();
        LocalDate today = LocalDate.now();

        List<CandidateLineVO> result = new ArrayList<>();
        for (Line line : lineRepository.findAllByOrderByIdAsc()) {
            result.add(evaluateLine(task, vehicle, remaining, line, queueMap, today));
        }
        result.sort(Comparator.comparing(CandidateLineVO::isAvailable).reversed()
                .thenComparing(CandidateLineVO::getResumeQueue)
                .thenComparing(CandidateLineVO::getRemainingLoad)
                .thenComparing(CandidateLineVO::getLineId));
        result.stream().filter(CandidateLineVO::isAvailable).findFirst()
                .ifPresent(vo -> vo.setRecommended(true));
        return result;
    }

    /**
     * 确认跨线恢复。并发口径：
     * ① 两名值班员同时处置同一车辆 —— 任务 CAS 只允许一方改写成功；
     * ② 确认瞬间目标工位被占用 / 停用 —— 工位 CAS 占不到位即失败；
     * 失败方拿到最新去向提示，事务整体回滚，不留半迁移。
     * 隔离级别用 READ_COMMITTED：冲突失败后要能读到胜方刚提交的去向记录。
     */
    @Transactional(isolation = Isolation.READ_COMMITTED)
    public TransferResultVO confirm(Long taskId, TransferRequest request) {
        Task task = taskRepository.findById(taskId)
                .orElseThrow(() -> new BizException("检测任务不存在：id=" + taskId));
        if (!"CHECKING".equals(task.getStatus()) && !"RETEST".equals(task.getStatus())) {
            throw new BizException("任务 " + task.getTaskNo() + " 已结束（" + StationDict.taskStatusName(task.getStatus())
                    + "），不能跨线恢复");
        }
        Vehicle vehicle = vehicleRepository.findById(task.getVehicleId())
                .orElseThrow(() -> new BizException("任务 " + task.getTaskNo() + " 关联车辆已丢失"));
        Station current = stationRepository.findById(task.getCurrentStationId())
                .orElseThrow(() -> new BizException("任务 " + task.getTaskNo() + " 当前工位已丢失"));
        if (!"FAULT".equals(current.getStatus())) {
            throw new BizException("车辆「" + vehicle.getPlateNo() + "」当前工位已不处于故障状态"
                    + "（可能已被其他值班员处置，或故障已解除可回原线继续），请刷新查看最新状态");
        }
        if (request.getToLineId() == null) {
            throw new BizException("请选择目标检测线");
        }
        Line target = lineRepository.findById(request.getToLineId())
                .orElseThrow(() -> new BizException("目标检测线不存在：id=" + request.getToLineId()));
        Line source = lineRepository.findById(task.getLineId())
                .orElseThrow(() -> new BizException("任务关联检测线已丢失"));

        // 服务端重新评估目标线，不信任页面快照；硬条件不过即拒绝并说明原因
        CandidateLineVO eval = evaluateLine(task, vehicle, remainingTypes(task.getCurrentSeqNo()),
                target, queueMap(), LocalDate.now());
        if (!eval.isAvailable()) {
            throw new BizException("目标线「" + target.getLineNo() + " " + target.getLineName() + "」不可承接："
                    + String.join("；", eval.getReasons()));
        }
        Station resume = stationRepository.findById(eval.getResumeStationId())
                .orElseThrow(() -> new BizException("目标线承接工位已丢失"));

        // ① CAS 占用目标工位：确认瞬间被占用 / 停用 / 故障则占不到位
        if (stationRepository.occupyIfIdle(resume.getId()) == 0) {
            Station latest = stationRepository.findById(resume.getId()).orElse(resume);
            throw new BizException("目标工位「" + target.getLineNo() + " · " + resume.getStationName()
                    + "」刚被占用或状态已变为「" + StationDict.stationStatusName(latest.getStatus())
                    + "」，本次转线未生效，请刷新后重新选择");
        }
        // ② CAS 迁移任务：两名值班员同时处置同一车辆，只允许一次成功
        int moved = taskRepository.transferLine(task.getId(), target.getId(), resume.getId(),
                source.getId(), current.getId());
        if (moved == 0) {
            throw new BizException("处置冲突：" + latestWhereabouts(task.getId(), vehicle.getPlateNo())
                    + "，本次操作未生效，已为您刷新最新去向");
        }
        // ③ 释放旧工位：占用则释放；故障工位保持故障，待维修解除后车辆才可回原线
        stationRepository.releaseIfOccupied(current.getId());
        // ④ 处置记录：换线凭据，与任务、报告共同构成同一份连续检测链
        TransferRecord record = new TransferRecord();
        record.setTaskId(task.getId());
        record.setTaskNo(task.getTaskNo());
        record.setPlateNo(vehicle.getPlateNo());
        record.setFromLineId(source.getId());
        record.setFromLineNo(source.getLineNo());
        record.setToLineId(target.getId());
        record.setToLineNo(target.getLineNo());
        record.setFromStationId(current.getId());
        record.setToStationId(resume.getId());
        record.setSeqNo(task.getCurrentSeqNo());
        record.setReason(request.getReason() == null || request.getReason().isBlank()
                ? current.getStationName() + "工位故障，跨线恢复" : request.getReason());
        record.setOperatorName(request.getOperatorName() == null || request.getOperatorName().isBlank()
                ? "值班员" : request.getOperatorName());
        record.setCreateTime(LocalDateTime.now());
        transferRepository.save(record);

        TransferResultVO result = new TransferResultVO();
        result.setTask(taskFlowService.getTask(task.getId()));
        result.setRecord(toRecordVO(record, Map.of(current.getId(), current, resume.getId(), resume)));
        return result;
    }

    /**
     * 最近处置记录（处置台底部台账）
     */
    public List<TransferRecordVO> recentRecords() {
        List<TransferRecord> records = transferRepository.findTop20ByOrderByIdDesc();
        Set<Long> stationIds = records.stream()
                .flatMap(r -> java.util.stream.Stream.of(r.getFromStationId(), r.getToStationId()))
                .collect(Collectors.toSet());
        Map<Long, Station> stationMap = stationRepository.findAllById(stationIds).stream()
                .collect(Collectors.toMap(Station::getId, s -> s, (a, b) -> a));
        List<TransferRecordVO> result = new ArrayList<>();
        for (TransferRecord record : records) {
            result.add(toRecordVO(record, stationMap));
        }
        return result;
    }

    // ---------------- 候选评估 ----------------

    /**
     * 评估单条检测线：硬条件逐条收集排除原因；全部通过则给出推荐依据与负载。
     */
    private CandidateLineVO evaluateLine(Task task, Vehicle vehicle, List<String> remaining, Line line,
                                         Map<Long, Long> queueMap, LocalDate today) {
        CandidateLineVO vo = new CandidateLineVO();
        vo.setLineId(line.getId());
        vo.setLineNo(line.getLineNo());
        vo.setLineName(line.getLineName());
        vo.setLineType(line.getLineType());
        vo.setLineTypeName(StationDict.lineTypeName(line.getLineType()));
        vo.setAcceptTypeNames(acceptTypesOf(line).stream().map(StationDict::vehicleTypeName).toList());

        List<String> reasons = new ArrayList<>();
        boolean self = line.getId().equals(task.getLineId());
        if (self) {
            reasons.add("本线为故障线，车辆正等待迁出，不能作为目标线");
        }
        if (!"RUNNING".equals(line.getStatus())) {
            reasons.add("检测线已停用，不能接车");
        }
        if (!acceptTypesOf(line).contains(vehicle.getVehicleType())) {
            reasons.add("不具备「" + StationDict.vehicleTypeName(vehicle.getVehicleType()) + "」承接能力（可承接："
                    + (vo.getAcceptTypeNames().isEmpty() ? "无" : String.join("、", vo.getAcceptTypeNames())) + "）");
        }

        List<Station> stations = stationRepository.findByLineIdOrderBySeqNoAsc(line.getId());
        List<Station> remainingStations = stations.stream()
                .filter(s -> remaining.contains(s.getStationType())).toList();
        List<String> targetTypes = remainingStations.stream().map(Station::getStationType).toList();
        boolean sequenceMatch = targetTypes.equals(remaining);
        if (!sequenceMatch) {
            List<String> missing = remaining.stream()
                    .filter(type -> !targetTypes.contains(type))
                    .map(StationDict::stationName).toList();
            reasons.add(missing.isEmpty()
                    ? "剩余工位顺序与本线工位编排不一致"
                    : "缺少剩余工位：" + String.join("、", missing) + "，无法按原顺序继续");
        } else if (!self) {
            Station resume = remainingStations.get(0);
            vo.setResumeStationId(resume.getId());
            vo.setResumeStationName(resume.getStationName());
            vo.setResumeStationStatus(resume.getStatus());
            vo.setResumeStationStatusName(StationDict.stationStatusName(resume.getStatus()));
            vo.setResumeQueue(queueMap.getOrDefault(resume.getId(), 0L));
            vo.setRemainingLoad(remainingStations.stream()
                    .mapToLong(s -> queueMap.getOrDefault(s.getId(), 0L)).sum());
            if ("FAULT".equals(resume.getStatus())) {
                reasons.add("目标工位「" + resume.getStationName() + "」故障中，暂不可接入");
            } else if ("OCCUPIED".equals(resume.getStatus())) {
                reasons.add("目标工位「" + resume.getStationName() + "」正被占用，暂不可接入");
            }
            for (Station station : remainingStations) {
                if (!station.getId().equals(resume.getId()) && "FAULT".equals(station.getStatus())) {
                    reasons.add("下游工位「" + station.getStationName() + "」故障中，转线后会再次卡住");
                }
            }
        }

        for (Device device : deviceRepository.findDevicesOfLine(line.getId())) {
            if (device.getNextCalDate().isBefore(today)) {
                long days = ChronoUnit.DAYS.between(device.getNextCalDate(), today);
                reasons.add("设备「" + device.getDeviceName() + "（" + device.getModel() + "）」标定已超期 "
                        + days + " 天，负载再低也不可转入");
            } else if ("FAIL".equals(device.getCalResult())) {
                reasons.add("设备「" + device.getDeviceName() + "（" + device.getModel() + "）」标定结论不合格");
            }
        }

        vo.setAvailable(reasons.isEmpty());
        if (vo.isAvailable()) {
            reasons.add("剩余工位顺序一致（" + remaining.stream()
                    .map(StationDict::stationName).collect(Collectors.joining("→")) + "）");
            reasons.add("可承接「" + StationDict.vehicleTypeName(vehicle.getVehicleType()) + "」，标定设备全部有效");
            reasons.add("目标工位「" + vo.getResumeStationName() + "」空闲，排队 " + vo.getResumeQueue()
                    + " 辆，剩余工位在检 " + vo.getRemainingLoad() + " 辆");
        }
        vo.setReasons(reasons);
        return vo;
    }

    // ---------------- 工具 ----------------

    /** 尚未完成的工位类型（从当前工位到总检，保持原顺序） */
    private List<String> remainingTypes(Integer currentSeqNo) {
        int from = Math.max(1, currentSeqNo == null ? 1 : currentSeqNo);
        return new ArrayList<>(StationDict.STATION_ORDER.subList(from - 1, StationDict.STATION_ORDER.size()));
    }

    private List<String> acceptTypesOf(Line line) {
        if (line.getAcceptTypes() == null || line.getAcceptTypes().isBlank()) {
            return List.of();
        }
        return List.of(line.getAcceptTypes().split(","));
    }

    private Map<Long, Long> queueMap() {
        return taskRepository.countQueueGroupByStation().stream()
                .collect(Collectors.toMap(StationQueueDTO::getStationId, StationQueueDTO::getQueueCount, (a, b) -> a));
    }

    /** 处置冲突时拼出该车辆的最新去向 */
    private String latestWhereabouts(Long taskId, String plateNo) {
        List<TransferRecord> records = transferRepository.findByTaskIdOrderByIdDesc(taskId);
        if (!records.isEmpty()) {
            TransferRecord last = records.get(0);
            return "车辆「" + plateNo + "」刚由 " + last.getOperatorName() + " 转往 "
                    + last.getToLineNo() + "（第 " + last.getSeqNo() + " 工位）";
        }
        Task latest = taskRepository.findById(taskId).orElse(null);
        String lineNo = latest == null ? "?"
                : lineRepository.findById(latest.getLineId()).map(Line::getLineNo).orElse("?");
        return "车辆「" + plateNo + "」已被处置至 " + lineNo;
    }

    private TransferRecordVO toRecordVO(TransferRecord record, Map<Long, Station> stationMap) {
        TransferRecordVO vo = new TransferRecordVO();
        vo.setId(record.getId());
        vo.setTaskId(record.getTaskId());
        vo.setTaskNo(record.getTaskNo());
        vo.setPlateNo(record.getPlateNo());
        vo.setFromLineNo(record.getFromLineNo());
        vo.setToLineNo(record.getToLineNo());
        Station from = stationMap.get(record.getFromStationId());
        Station to = stationMap.get(record.getToStationId());
        vo.setFromStationName(from == null ? "" : from.getStationName());
        vo.setToStationName(to == null ? "" : to.getStationName());
        vo.setSeqNo(record.getSeqNo());
        vo.setReason(record.getReason());
        vo.setOperatorName(record.getOperatorName());
        vo.setCreateTime(record.getCreateTime());
        return vo;
    }
}
