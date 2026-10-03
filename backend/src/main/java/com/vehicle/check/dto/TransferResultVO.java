package com.vehicle.check.dto;

import lombok.Data;

/**
 * 跨线恢复确认结果：迁移后的任务视图 + 处置记录
 */
@Data
public class TransferResultVO {

    private TaskVO task;
    private TransferRecordVO record;
}
