package com.vehicle.check.dto;

import java.time.LocalDateTime;

import lombok.Data;

/**
 * 跨线恢复处置记录视图
 */
@Data
public class TransferRecordVO {

    private Long id;
    private Long taskId;
    private String taskNo;
    private String plateNo;
    private String fromLineNo;
    private String toLineNo;
    private String fromStationName;
    private String toStationName;
    private Integer seqNo;
    private String reason;
    private String operatorName;
    private LocalDateTime createTime;
}
