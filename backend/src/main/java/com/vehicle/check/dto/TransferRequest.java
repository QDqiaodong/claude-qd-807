package com.vehicle.check.dto;

import lombok.Data;

/**
 * 跨线恢复确认请求
 */
@Data
public class TransferRequest {

    private Long toLineId;
    private String operatorName;
    private String reason;
}
