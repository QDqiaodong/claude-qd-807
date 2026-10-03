package com.vehicle.check.dto;

import java.util.ArrayList;
import java.util.List;

import lombok.Data;

/**
 * 受故障工位影响、等待跨线恢复处置的在检车辆
 */
@Data
public class AffectedTaskVO {

    private Long taskId;
    private String taskNo;
    private String plateNo;
    private String ownerName;
    private String vehicleType;
    private String vehicleTypeName;
    private Long lineId;
    private String lineNo;
    private String lineName;
    private Long faultStationId;
    private String faultStationType;
    private String faultStationName;
    private Integer currentSeqNo;
    private String status;
    private String statusName;
    private Integer retestTimes;
    private String driverName;
    /** 已完成的工位名（结果与操作痕迹原样保留的部分） */
    private List<String> doneStations = new ArrayList<>();
    /** 尚未完成、需要在目标线继续的工位名 */
    private List<String> remainingStations = new ArrayList<>();
    /** 已产生的不合格记录数（换线不得洗掉） */
    private Long failRecordCount;
    /** 复检任务关联的原报告编号 */
    private String originReportNo;
}
