package com.vehicle.check.domain;

import java.time.LocalDateTime;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import lombok.Data;

/**
 * 跨线恢复处置记录：工位故障后车辆从一条检测线迁往另一条线的完整轨迹。
 * 任务、流水线进度与最终报告共用同一份连续检测链，本表是该链条上「换线」环节的凭据。
 */
@Data
@Entity
@Table(name = "vc_transfer_record")
public class TransferRecord {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "task_id", nullable = false)
    private Long taskId;

    @Column(name = "task_no", nullable = false)
    private String taskNo;

    @Column(name = "plate_no", nullable = false)
    private String plateNo;

    @Column(name = "from_line_id", nullable = false)
    private Long fromLineId;

    @Column(name = "from_line_no", nullable = false)
    private String fromLineNo;

    @Column(name = "to_line_id", nullable = false)
    private Long toLineId;

    @Column(name = "to_line_no", nullable = false)
    private String toLineNo;

    @Column(name = "from_station_id", nullable = false)
    private Long fromStationId;

    @Column(name = "to_station_id", nullable = false)
    private Long toStationId;

    @Column(name = "seq_no", nullable = false)
    private Integer seqNo;

    @Column(name = "reason")
    private String reason;

    @Column(name = "operator_name", nullable = false)
    private String operatorName;

    @Column(name = "create_time")
    private LocalDateTime createTime;
}
