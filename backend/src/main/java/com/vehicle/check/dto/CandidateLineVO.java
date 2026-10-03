package com.vehicle.check.dto;

import java.util.ArrayList;
import java.util.List;

import lombok.Data;

/**
 * 跨线恢复候选检测线评估结果：为什么推荐 / 为什么排除，逐条给出原因。
 * 硬条件（线状态、剩余工位顺序、车型承接、标定有效、目标工位可接入）不满足即排除；
 * 负载（目标工位排队、剩余工位在检）只在可用线之间排序，不能凌驾硬条件。
 */
@Data
public class CandidateLineVO {

    private Long lineId;
    private String lineNo;
    private String lineName;
    private String lineType;
    private String lineTypeName;
    private List<String> acceptTypeNames = new ArrayList<>();
    /** true=可确认转入；false=仅展示排除原因 */
    private boolean available;
    /** 可用线中负载最低的一条 */
    private boolean recommended;
    /** 推荐依据或排除原因 */
    private List<String> reasons = new ArrayList<>();

    private Long resumeStationId;
    private String resumeStationName;
    private String resumeStationStatus;
    private String resumeStationStatusName;
    /** 目标工位当前排队车辆数 */
    private Long resumeQueue = 0L;
    /** 剩余工位（含目标工位）在该线的总在检车辆数 */
    private Long remainingLoad = 0L;
}
