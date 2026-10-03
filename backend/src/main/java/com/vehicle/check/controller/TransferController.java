package com.vehicle.check.controller;

import java.util.List;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.vehicle.check.common.ApiResponse;
import com.vehicle.check.dto.AffectedTaskVO;
import com.vehicle.check.dto.CandidateLineVO;
import com.vehicle.check.dto.TransferRecordVO;
import com.vehicle.check.dto.TransferRequest;
import com.vehicle.check.dto.TransferResultVO;
import com.vehicle.check.service.TransferService;

/**
 * 在检车辆跨线恢复处置台
 */
@RestController
@RequestMapping("/api/transfer")
public class TransferController {

    private final TransferService transferService;

    public TransferController(TransferService transferService) {
        this.transferService = transferService;
    }

    /** 受影响车辆：当前工位故障的在检 / 复检任务 */
    @GetMapping("/affected")
    public ApiResponse<List<AffectedTaskVO>> affected() {
        return ApiResponse.success(transferService.affectedVehicles());
    }

    /** 候选检测线评估：推荐 / 排除原因逐条展示，负载只在可用线之间排序 */
    @GetMapping("/tasks/{taskId}/candidates")
    public ApiResponse<List<CandidateLineVO>> candidates(@PathVariable Long taskId) {
        return ApiResponse.success(transferService.candidates(taskId));
    }

    /** 确认跨线恢复：单事务完成占位、迁移、释放与处置记录 */
    @PostMapping("/tasks/{taskId}/confirm")
    public ApiResponse<TransferResultVO> confirm(@PathVariable Long taskId, @RequestBody TransferRequest request) {
        TransferResultVO result = transferService.confirm(taskId, request);
        return ApiResponse.success("跨线恢复成功：车辆 " + result.getRecord().getPlateNo() + " 已转往 "
                + result.getRecord().getToLineNo() + " · " + result.getRecord().getToStationName() + "工位", result);
    }

    /** 最近处置记录台账 */
    @GetMapping("/records")
    public ApiResponse<List<TransferRecordVO>> records() {
        return ApiResponse.success(transferService.recentRecords());
    }
}
