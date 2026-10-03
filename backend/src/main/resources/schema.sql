-- ============================================================
-- 机动车检测站 · 工位与检测报告管理  （库名 vehicle_check）
-- 说明：
--   1. ddl-auto: none，所有表由本脚本建立
--   2. vc_vehicle.owner_id_no / owner_phone 为 VARBINARY，
--      存的是 AES_ENCRYPT 密文，实体用 @ColumnTransformer 读写
--   3. vc_task.brake_rate 库里存小数(0.6230)，实体里是百分比(62.30)
-- ============================================================

CREATE DATABASE IF NOT EXISTS `vehicle_check`
  DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE `vehicle_check`;

SET NAMES utf8mb4;

-- ---------------- 1. 检测线 ----------------
CREATE TABLE IF NOT EXISTS `vc_line` (
  `id`             BIGINT       NOT NULL AUTO_INCREMENT,
  `line_no`        VARCHAR(32)  NOT NULL COMMENT '线号',
  `line_name`      VARCHAR(64)  NOT NULL COMMENT '线名',
  `line_type`      VARCHAR(24)  NOT NULL COMMENT 'SECURITY安检/ENVIRONMENT环保/COMPREHENSIVE综检',
  `status`         VARCHAR(16)  NOT NULL DEFAULT 'RUNNING' COMMENT 'RUNNING运行/STOPPED停用',
  `accept_types`   VARCHAR(64)  NOT NULL DEFAULT '' COMMENT '可承接车型，逗号分隔 SMALL_BUS/TRUCK/HAZMAT',
  `daily_capacity` INT          NOT NULL DEFAULT 0 COMMENT '日检测能力(台)',
  `remark`         VARCHAR(200) NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_line_no` (`line_no`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------- 2. 工位 ----------------
CREATE TABLE IF NOT EXISTS `vc_station` (
  `id`           BIGINT       NOT NULL AUTO_INCREMENT,
  `line_id`      BIGINT       NOT NULL,
  `station_type` VARCHAR(24)  NOT NULL COMMENT 'LOGIN/APPEARANCE/EMISSION/BRAKE/LIGHT/CHASSIS/FINAL',
  `station_name` VARCHAR(32)  NOT NULL,
  `seq_no`       INT          NOT NULL COMMENT '顺序号 1..7',
  `status`       VARCHAR(16)  NOT NULL DEFAULT 'IDLE' COMMENT 'IDLE空闲/OCCUPIED占用/FAULT故障',
  `device_id`    BIGINT       NULL,
  `remark`       VARCHAR(200) NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_line_seq` (`line_id`, `seq_no`),
  KEY `idx_station_type` (`station_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------- 3. 车辆与送检 ----------------
CREATE TABLE IF NOT EXISTS `vc_vehicle` (
  `id`           BIGINT          NOT NULL AUTO_INCREMENT,
  `plate_no`     VARCHAR(32)     NOT NULL COMMENT '车牌',
  `owner_name`   VARCHAR(64)     NOT NULL COMMENT '车主',
  `owner_id_no`  VARBINARY(128)  NULL     COMMENT '身份证号(AES密文)',
  `owner_phone`  VARBINARY(128)  NULL     COMMENT '手机号(AES密文)',
  `vehicle_type` VARCHAR(24)     NOT NULL COMMENT 'SMALL_BUS小型客车/TRUCK货车/HAZMAT危化品车',
  `register_date` DATE           NOT NULL COMMENT '注册日期',
  `mileage`      INT             NOT NULL DEFAULT 0 COMMENT '里程(km)',
  `fuel_type`    VARCHAR(16)     NOT NULL COMMENT 'GASOLINE/DIESEL/LNG/ELECTRIC',
  `submitter`    VARCHAR(64)     NOT NULL COMMENT '送检人',
  `appoint_time` DATETIME        NULL     COMMENT '预约时间',
  `create_time`  DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_plate_no` (`plate_no`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------- 4. 检测任务 ----------------
CREATE TABLE IF NOT EXISTS `vc_task` (
  `id`                 BIGINT        NOT NULL AUTO_INCREMENT,
  `task_no`            VARCHAR(32)   NOT NULL,
  `vehicle_id`         BIGINT        NOT NULL,
  `line_id`            BIGINT        NOT NULL,
  `current_station_id` BIGINT        NULL COMMENT '当前工位',
  `current_seq_no`     INT           NOT NULL DEFAULT 1 COMMENT '当前工位顺序号',
  `status`             VARCHAR(16)   NOT NULL DEFAULT 'CHECKING' COMMENT 'CHECKING在检/PASS合格/FAIL不合格/RETEST复检',
  `driver_id`          BIGINT        NULL COMMENT '引车员',
  `schedule_hour`      INT           NULL COMMENT '排班小时段 8..17',
  `check_date`         DATE          NOT NULL,
  `co_value`           DECIMAL(6,3)  NULL COMMENT '尾气 CO 值(%)',
  `hc_value`           INT           NULL COMMENT '尾气 HC 值(ppm)',
  `brake_rate`         DECIMAL(6,4)  NULL COMMENT '制动率(库存小数 0.6230 = 62.30%)',
  `light_intensity`    INT           NULL COMMENT '灯光强度(cd)',
  `chassis_defects`    VARCHAR(200)  NULL COMMENT '底盘缺陷项',
  `retest_times`       INT           NOT NULL DEFAULT 0 COMMENT '复检次数',
  `create_time`        DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `finish_time`        DATETIME      NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_task_no` (`task_no`),
  KEY `idx_task_status` (`status`),
  KEY `idx_task_check_date` (`check_date`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------- 5. 工位流转记录 ----------------
CREATE TABLE IF NOT EXISTS `vc_task_station_record` (
  `id`            BIGINT       NOT NULL AUTO_INCREMENT,
  `task_id`       BIGINT       NOT NULL,
  `station_id`    BIGINT       NOT NULL,
  `station_type`  VARCHAR(24)  NOT NULL,
  `seq_no`        INT          NOT NULL,
  `item_name`     VARCHAR(64)  NOT NULL COMMENT '检测项名称',
  `result`        VARCHAR(16)  NOT NULL COMMENT 'PASS/FAIL',
  `value_text`    VARCHAR(200) NULL COMMENT '检测值文本',
  `operator_name` VARCHAR(64)  NULL COMMENT '操作员',
  `driver_id`     BIGINT       NULL,
  `record_time`   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_record_task` (`task_id`),
  KEY `idx_record_station_type` (`station_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------- 6. 检测报告 ----------------
CREATE TABLE IF NOT EXISTS `vc_report` (
  `id`             BIGINT       NOT NULL AUTO_INCREMENT,
  `report_no`      VARCHAR(32)  NOT NULL,
  `task_id`        BIGINT       NOT NULL,
  `plate_no`       VARCHAR(32)  NOT NULL,
  `line_no`        VARCHAR(32)  NOT NULL,
  `conclusion`     VARCHAR(16)  NOT NULL COMMENT 'PASS/FAIL',
  `conclusion_name` VARCHAR(16) NOT NULL COMMENT '合格/不合格',
  `snapshot`       TEXT         NULL COMMENT '各分项结果快照',
  `fail_items`     VARCHAR(500) NULL COMMENT '不合格项',
  `signer`         VARCHAR(64)  NOT NULL COMMENT '签发人',
  `sign_date`      DATE         NOT NULL COMMENT '签发日期',
  `retest_of`      VARCHAR(32)  NULL COMMENT '复检关联的原报告编号',
  `create_time`    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_report_no` (`report_no`),
  KEY `idx_report_task` (`task_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------- 7. 跨线恢复处置记录 ----------------
CREATE TABLE IF NOT EXISTS `vc_transfer_record` (
  `id`               BIGINT       NOT NULL AUTO_INCREMENT,
  `task_id`          BIGINT       NOT NULL COMMENT '检测任务',
  `task_no`          VARCHAR(32)  NOT NULL,
  `plate_no`         VARCHAR(32)  NOT NULL COMMENT '车牌（冗余，便于展示）',
  `from_line_id`     BIGINT       NOT NULL,
  `from_line_no`     VARCHAR(32)  NOT NULL,
  `to_line_id`       BIGINT       NOT NULL,
  `to_line_no`       VARCHAR(32)  NOT NULL,
  `from_station_id`  BIGINT       NOT NULL COMMENT '迁出工位（故障工位）',
  `to_station_id`    BIGINT       NOT NULL COMMENT '目标线承接工位',
  `seq_no`           INT          NOT NULL COMMENT '转线发生时的工位顺序号',
  `reason`           VARCHAR(200) NULL COMMENT '处置原因',
  `operator_name`    VARCHAR(64)  NOT NULL COMMENT '值班员',
  `create_time`      DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_transfer_task` (`task_id`),
  KEY `idx_transfer_time` (`create_time`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------- 8. 设备台账 ----------------
CREATE TABLE IF NOT EXISTS `vc_device` (
  `id`             BIGINT      NOT NULL AUTO_INCREMENT,
  `device_name`    VARCHAR(64) NOT NULL,
  `model`          VARCHAR(64) NOT NULL COMMENT '型号',
  `device_type`    VARCHAR(24) NOT NULL COMMENT '用途分类',
  `last_cal_date`  DATE        NOT NULL COMMENT '上次标定日期',
  `next_cal_date`  DATE        NOT NULL COMMENT '下次标定日期',
  `cal_org`        VARCHAR(64) NULL COMMENT '标定机构',
  `cal_result`     VARCHAR(16) NULL COMMENT '标定结论 PASS/FAIL',
  `status`         VARCHAR(16) NOT NULL DEFAULT 'NORMAL' COMMENT 'NORMAL正常/DUE临近/OVERDUE超期',
  PRIMARY KEY (`id`),
  KEY `idx_device_next_cal` (`next_cal_date`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------- 9. 引车员 ----------------
CREATE TABLE IF NOT EXISTS `vc_driver` (
  `id`            BIGINT      NOT NULL AUTO_INCREMENT,
  `driver_name`   VARCHAR(64) NOT NULL,
  `cert_level`    VARCHAR(16) NOT NULL COMMENT '资质 A1/A2/B2/C1',
  `cert_no`       VARCHAR(64) NOT NULL COMMENT '资格证编号',
  `shift_hours`   VARCHAR(64) NOT NULL COMMENT '当日排班小时段，如 8,9,10,11',
  `checked_count` INT         NOT NULL DEFAULT 0 COMMENT '当日已检台次',
  `status`        VARCHAR(16) NOT NULL DEFAULT 'ON_DUTY' COMMENT 'ON_DUTY在岗/OFF_DUTY休息',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- 种子数据
-- ============================================================

-- 检测线（5 条；accept_types 为可承接车型）
INSERT INTO `vc_line` (`id`,`line_no`,`line_name`,`line_type`,`status`,`accept_types`,`daily_capacity`,`remark`) VALUES
 (1,'L01','安检一线','SECURITY','RUNNING','SMALL_BUS',120,'小型客车主线，7 工位全开'),
 (2,'L02','安检二线','SECURITY','RUNNING','SMALL_BUS,TRUCK',110,'货车与小型客车混线'),
 (3,'L03','环保尾气专用线','ENVIRONMENT','RUNNING','SMALL_BUS,TRUCK',90,'仅承接尾气复检'),
 (4,'L04','综检线','COMPREHENSIVE','RUNNING','SMALL_BUS,TRUCK',80,'综检与等级评定'),
 (5,'L05','危化品车专线','COMPREHENSIVE','STOPPED','HAZMAT',0,'设备标定中，暂停接车');

-- 工位（L01 / L02 / L04 各 7 个，L03 尾气复检 3 个，L05 危化品专线 7 个，共 31 个）
-- 说明：L01 尾气工位(3) 初始即故障 → 任务 1 成为「待跨线恢复」演示数据；
--       L02 底盘工位(13) 故障 → 候选评估时会被「下游工位故障」排除。
INSERT INTO `vc_station` (`id`,`line_id`,`station_type`,`station_name`,`seq_no`,`status`,`device_id`,`remark`) VALUES
 (1,1,'LOGIN','登录',1,'IDLE',NULL,'车辆唯一性确认'),
 (2,1,'APPEARANCE','外观',2,'IDLE',5,'车身与灯具外观查验'),
 (3,1,'EMISSION','尾气',3,'FAULT',1,'汽油车双怠速法（分析仪故障待修）'),
 (4,1,'BRAKE','制动',4,'IDLE',2,'滚筒反力式制动台'),
 (5,1,'LIGHT','灯光',5,'IDLE',3,'前照灯远光发光强度'),
 (6,1,'CHASSIS','底盘',6,'IDLE',6,'转向/悬挂/传动间隙'),
 (7,1,'FINAL','总检',7,'IDLE',NULL,'结论复核与签发'),
 (8,2,'LOGIN','登录',1,'IDLE',NULL,'证件与号牌核验'),
 (9,2,'APPEARANCE','外观',2,'OCCUPIED',12,'外廓尺寸与车身'),
 (10,2,'EMISSION','尾气',3,'IDLE',9,'柴油车自由加速法'),
 (11,2,'BRAKE','制动',4,'IDLE',10,'制动率与阻滞率'),
 (12,2,'LIGHT','灯光',5,'IDLE',11,'远近光偏移'),
 (13,2,'CHASSIS','底盘',6,'FAULT',13,'底盘间隙仪待修'),
 (14,2,'FINAL','总检',7,'IDLE',NULL,'报告签发'),
 (15,3,'LOGIN','登录',1,'IDLE',NULL,'尾气复检登录'),
 (16,3,'EMISSION','尾气',3,'IDLE',19,'尾气复检专用工位'),
 (17,3,'FINAL','总检',7,'IDLE',NULL,'复检结论复核'),
 (18,4,'LOGIN','登录',1,'IDLE',NULL,'综检登录'),
 (19,4,'APPEARANCE','外观',2,'IDLE',18,'综检外观查验'),
 (20,4,'EMISSION','尾气',3,'IDLE',14,'综检尾气检测'),
 (21,4,'BRAKE','制动',4,'IDLE',15,'综检制动台'),
 (22,4,'LIGHT','灯光',5,'IDLE',16,'综检灯光检测'),
 (23,4,'CHASSIS','底盘',6,'IDLE',17,'综检底盘测功'),
 (24,4,'FINAL','总检',7,'IDLE',NULL,'综检结论与等级评定'),
 (25,5,'LOGIN','登录',1,'IDLE',NULL,'危化品车登录'),
 (26,5,'APPEARANCE','外观',2,'IDLE',NULL,'危化品标识查验'),
 (27,5,'EMISSION','尾气',3,'IDLE',NULL,'危化品车尾气'),
 (28,5,'BRAKE','制动',4,'IDLE',NULL,'危化品车制动'),
 (29,5,'LIGHT','灯光',5,'IDLE',NULL,'危化品车灯光'),
 (30,5,'CHASSIS','底盘',6,'IDLE',NULL,'危化品车底盘'),
 (31,5,'FINAL','总检',7,'IDLE',NULL,'危化品车总检');

-- 车辆与送检（12 辆；身份证/手机号为 AES 密文）
INSERT INTO `vc_vehicle` (`id`,`plate_no`,`owner_name`,`owner_id_no`,`owner_phone`,`vehicle_type`,`register_date`,`mileage`,`fuel_type`,`submitter`,`appoint_time`,`create_time`) VALUES
 (1,'京A·Q8801','赵德柱',AES_ENCRYPT('110101198703124517','seed_key'),AES_ENCRYPT('13801018801','seed_key'),'SMALL_BUS','2017-05-12',96300,'GASOLINE','赵德柱','2026-09-27 09:00:00','2026-09-27 08:40:00'),
 (2,'京A·5T27K','孙丽华',AES_ENCRYPT('110108199205084226','seed_key'),AES_ENCRYPT('13910025572','seed_key'),'SMALL_BUS','2020-08-03',41200,'GASOLINE','孙丽华','2026-09-27 08:30:00','2026-09-27 08:22:00'),
 (3,'京B·沪D9371','周文斌',AES_ENCRYPT('310104198011206613','seed_key'),AES_ENCRYPT('13611209934','seed_key'),'TRUCK','2015-11-20',287400,'DIESEL','周文斌','2026-09-27 10:00:00','2026-09-27 09:05:00'),
 (4,'京A·N668P','吴秀英',AES_ENCRYPT('110105197406153128','seed_key'),AES_ENCRYPT('15801347765','seed_key'),'SMALL_BUS','2019-03-27',68900,'GASOLINE','吴秀英','2026-09-27 10:30:00','2026-09-27 09:12:00'),
 (5,'京B·危A0731','京运危化物流',AES_ENCRYPT('110112198209304415','seed_key'),AES_ENCRYPT('13701125590','seed_key'),'HAZMAT','2018-06-09',351200,'DIESEL','李调度','2026-09-27 11:00:00','2026-09-27 09:20:00'),
 (6,'京A·3M92X','郑海涛',AES_ENCRYPT('110106199511027739','seed_key'),AES_ENCRYPT('18600438821','seed_key'),'SMALL_BUS','2021-09-14',23800,'ELECTRIC','郑海涛','2026-09-27 13:00:00','2026-09-27 09:31:00'),
 (7,'京B·L2208挂','冀东货运',AES_ENCRYPT('130203197903186214','seed_key'),AES_ENCRYPT('13502247718','seed_key'),'TRUCK','2014-04-18',612700,'DIESEL','王队长','2026-09-27 14:00:00','2026-09-27 09:44:00'),
 (8,'京A·W7710','冯丽娟',AES_ENCRYPT('110107198812093641','seed_key'),AES_ENCRYPT('13401198876','seed_key'),'SMALL_BUS','2016-12-05',147900,'GASOLINE','冯丽娟','2026-09-27 15:00:00','2026-09-27 09:50:00'),
 (9,'京A·K339L','许建国',AES_ENCRYPT('110109197211267510','seed_key'),AES_ENCRYPT('15910632245','seed_key'),'SMALL_BUS','2013-07-30',208300,'GASOLINE','许建国','2026-09-27 16:00:00','2026-09-27 10:02:00'),
 (10,'京B·危B1182','滨海化工运输',AES_ENCRYPT('120115198605147728','seed_key'),AES_ENCRYPT('13820774431','seed_key'),'HAZMAT','2019-01-22',276900,'LNG','赵调度','2026-09-27 17:00:00','2026-09-27 10:11:00'),
 (11,'京A·R5502','何秋燕',AES_ENCRYPT('110111199308215529','seed_key'),AES_ENCRYPT('13717905568','seed_key'),'SMALL_BUS','2022-02-11',18600,'ELECTRIC','何秋燕','2026-09-28 09:00:00','2026-09-27 10:25:00'),
 (12,'京B·T8845','马志强',AES_ENCRYPT('110113198409173316','seed_key'),AES_ENCRYPT('13311506692','seed_key'),'TRUCK','2016-10-08',398500,'DIESEL','马志强','2026-09-28 10:00:00','2026-09-27 10:33:00');

-- 检测任务（10 条；brake_rate 库存小数）
INSERT INTO `vc_task` (`id`,`task_no`,`vehicle_id`,`line_id`,`current_station_id`,`current_seq_no`,`status`,`driver_id`,`schedule_hour`,`check_date`,`co_value`,`hc_value`,`brake_rate`,`light_intensity`,`chassis_defects`,`retest_times`,`create_time`,`finish_time`) VALUES
 (1,'TASK-20260927-001',1,1,3,3,'CHECKING',1,9,'2026-09-27',NULL,NULL,NULL,NULL,NULL,0,'2026-09-27 08:41:00',NULL),
 (2,'TASK-20260927-002',2,1,5,5,'CHECKING',1,8,'2026-09-27',0.120,32,NULL,NULL,NULL,0,'2026-09-27 08:23:00',NULL),
 (3,'TASK-20260927-003',3,1,6,6,'CHECKING',2,10,'2026-09-27',0.180,41,0.7130,18200,NULL,0,'2026-09-27 09:06:00',NULL),
 (4,'TASK-20260927-004',4,1,2,2,'CHECKING',2,11,'2026-09-27',NULL,NULL,NULL,NULL,NULL,0,'2026-09-27 09:13:00',NULL),
 (5,'TASK-20260927-005',5,1,7,7,'CHECKING',3,13,'2026-09-27',0.260,48,0.6640,16500,NULL,0,'2026-09-27 09:21:00',NULL),
 (6,'TASK-20260927-006',6,1,7,7,'PASS',4,9,'2026-09-27',0.090,21,0.7820,21500,'',0,'2026-09-27 09:32:00','2026-09-27 10:18:00'),
 (7,'TASK-20260927-007',7,2,7,7,'PASS',4,14,'2026-09-27',0.210,55,0.6910,19800,'',0,'2026-09-27 09:45:00','2026-09-27 11:02:00'),
 (8,'TASK-20260927-008',8,2,7,7,'FAIL',5,15,'2026-09-27',0.480,96,0.7120,17200,'制动管路渗漏',0,'2026-09-27 09:51:00','2026-09-27 11:26:00'),
 (9,'TASK-20260927-009',9,2,14,7,'FAIL',5,16,'2026-09-27',0.150,38,0.7350,20400,'转向横拉杆球头松旷',0,'2026-09-27 10:03:00','2026-09-27 11:41:00'),
 (10,'TASK-20260927-010',8,2,9,2,'RETEST',5,17,'2026-09-27',NULL,NULL,NULL,NULL,NULL,1,'2026-09-27 11:27:00',NULL);

-- 工位流转记录（带各工位结果值）
INSERT INTO `vc_task_station_record` (`id`,`task_id`,`station_id`,`station_type`,`seq_no`,`item_name`,`result`,`value_text`,`operator_name`,`driver_id`,`record_time`) VALUES
 (1,1,1,'LOGIN',1,'车辆唯一性确认','PASS','车牌 京A·Q8801 与行驶证一致','陈登录',1,'2026-09-27 08:45:00'),
 (2,1,2,'APPEARANCE',2,'外观与灯具查验','PASS','外观缺陷 0 项','刘外观',1,'2026-09-27 08:58:00'),
 (3,2,1,'LOGIN',1,'车辆唯一性确认','PASS','车牌 京A·5T27K 一致','陈登录',1,'2026-09-27 08:26:00'),
 (4,2,2,'APPEARANCE',2,'外观与灯具查验','PASS','外观缺陷 1 项（后杠轻微划痕）','刘外观',1,'2026-09-27 08:39:00'),
 (5,2,3,'EMISSION',3,'尾气 CO/HC 检测','PASS','CO=0.120%，HC=32ppm','周尾气',1,'2026-09-27 08:52:00'),
 (6,2,4,'BRAKE',4,'制动率检测','PASS','制动率 74.50%','吴制动',1,'2026-09-27 09:07:00'),
 (7,3,1,'LOGIN',1,'车辆唯一性确认','PASS','车牌 京B·沪D9371 一致','陈登录',2,'2026-09-27 09:09:00'),
 (8,3,2,'APPEARANCE',2,'外观与灯具查验','PASS','外观缺陷 2 项','刘外观',2,'2026-09-27 09:21:00'),
 (9,3,3,'EMISSION',3,'尾气 CO/HC 检测','PASS','CO=0.180%，HC=41ppm','周尾气',2,'2026-09-27 09:34:00'),
 (10,3,4,'BRAKE',4,'制动率检测','PASS','制动率 71.30%','吴制动',2,'2026-09-27 09:48:00'),
 (11,3,5,'LIGHT',5,'前照灯发光强度','PASS','灯光强度 18200cd','孙灯光',2,'2026-09-27 10:01:00'),
 (12,4,1,'LOGIN',1,'车辆唯一性确认','PASS','车牌 京A·N668P 一致','陈登录',2,'2026-09-27 09:16:00'),
 (13,5,1,'LOGIN',1,'车辆唯一性确认','PASS','车牌 京B·危A0731 一致','陈登录',3,'2026-09-27 09:24:00'),
 (14,5,2,'APPEARANCE',2,'外观与灯具查验','PASS','危化品标识齐全，缺陷 1 项','刘外观',3,'2026-09-27 09:38:00'),
 (15,5,3,'EMISSION',3,'尾气 CO/HC 检测','PASS','CO=0.260%，HC=48ppm','周尾气',3,'2026-09-27 09:52:00'),
 (16,5,4,'BRAKE',4,'制动率检测','PASS','制动率 66.40%','吴制动',3,'2026-09-27 10:07:00'),
 (17,5,5,'LIGHT',5,'前照灯发光强度','PASS','灯光强度 16500cd','孙灯光',3,'2026-09-27 10:21:00'),
 (18,5,6,'CHASSIS',6,'底盘间隙与转向系','PASS','底盘缺陷 0 项','郑底盘',3,'2026-09-27 10:36:00'),
 (19,6,1,'LOGIN',1,'车辆唯一性确认','PASS','车牌 京A·3M92X 一致','陈登录',4,'2026-09-27 09:35:00'),
 (20,6,2,'APPEARANCE',2,'外观与灯具查验','PASS','外观缺陷 0 项','刘外观',4,'2026-09-27 09:44:00'),
 (21,6,3,'EMISSION',3,'尾气 CO/HC 检测','PASS','CO=0.090%，HC=21ppm','周尾气',4,'2026-09-27 09:53:00'),
 (22,6,4,'BRAKE',4,'制动率检测','PASS','制动率 78.20%','吴制动',4,'2026-09-27 10:02:00'),
 (23,6,5,'LIGHT',5,'前照灯发光强度','PASS','灯光强度 21500cd','孙灯光',4,'2026-09-27 10:09:00'),
 (24,6,6,'CHASSIS',6,'底盘间隙与转向系','PASS','底盘缺陷 0 项','郑底盘',4,'2026-09-27 10:14:00'),
 (25,6,7,'FINAL',7,'总检复核','PASS','全部工位合格，同意签发','何总检',4,'2026-09-27 10:18:00'),
 (26,7,1,'LOGIN',1,'车辆唯一性确认','PASS','车牌 京B·L2208挂 一致','陈登录',4,'2026-09-27 09:48:00'),
 (27,7,2,'APPEARANCE',2,'外观与灯具查验','PASS','外观缺陷 1 项','刘外观',4,'2026-09-27 10:01:00'),
 (28,7,3,'EMISSION',3,'尾气 CO/HC 检测','PASS','CO=0.210%，HC=55ppm','周尾气',4,'2026-09-27 10:16:00'),
 (29,7,4,'BRAKE',4,'制动率检测','PASS','制动率 69.10%','吴制动',4,'2026-09-27 10:34:00'),
 (30,7,5,'LIGHT',5,'前照灯发光强度','PASS','灯光强度 19800cd','孙灯光',4,'2026-09-27 10:47:00'),
 (31,7,6,'CHASSIS',6,'底盘间隙与转向系','PASS','底盘缺陷 0 项','郑底盘',4,'2026-09-27 10:56:00'),
 (32,7,7,'FINAL',7,'总检复核','PASS','全部工位合格，同意签发','何总检',4,'2026-09-27 11:02:00'),
 (33,8,1,'LOGIN',1,'车辆唯一性确认','PASS','车牌 京A·W7710 一致','陈登录',5,'2026-09-27 09:54:00'),
 (34,8,2,'APPEARANCE',2,'外观与灯具查验','PASS','外观缺陷 2 项','刘外观',5,'2026-09-27 10:08:00'),
 (35,8,3,'EMISSION',3,'尾气 CO/HC 检测','FAIL','CO=0.480%，HC=96ppm（CO 超限值 0.300%）','周尾气',5,'2026-09-27 10:23:00'),
 (36,8,4,'BRAKE',4,'制动率检测','PASS','制动率 71.20%','吴制动',5,'2026-09-27 10:41:00'),
 (37,8,5,'LIGHT',5,'前照灯发光强度','PASS','灯光强度 17200cd','孙灯光',5,'2026-09-27 10:58:00'),
 (38,8,6,'CHASSIS',6,'底盘间隙与转向系','FAIL','制动管路渗漏','郑底盘',5,'2026-09-27 11:14:00'),
 (39,8,7,'FINAL',7,'总检复核','FAIL','关键项不合格 2 项，判定不合格','何总检',5,'2026-09-27 11:26:00'),
 (40,9,1,'LOGIN',1,'车辆唯一性确认','PASS','车牌 京A·K339L 一致','陈登录',5,'2026-09-27 10:06:00'),
 (41,9,2,'APPEARANCE',2,'外观与灯具查验','PASS','外观缺陷 3 项（超限）','刘外观',5,'2026-09-27 10:19:00'),
 (42,9,3,'EMISSION',3,'尾气 CO/HC 检测','PASS','CO=0.150%，HC=38ppm','周尾气',5,'2026-09-27 10:33:00'),
 (43,9,4,'BRAKE',4,'制动率检测','PASS','制动率 73.50%','吴制动',5,'2026-09-27 10:49:00'),
 (44,9,5,'LIGHT',5,'前照灯发光强度','PASS','灯光强度 20400cd','孙灯光',5,'2026-09-27 11:05:00'),
 (45,9,6,'CHASSIS',6,'底盘间隙与转向系','FAIL','转向横拉杆球头松旷','郑底盘',5,'2026-09-27 11:41:00'),
 (46,10,1,'LOGIN',1,'车辆唯一性确认','PASS','车牌 京A·W7710 复检登录','陈登录',5,'2026-09-27 17:05:00'),
 (47,9,14,'FINAL',7,'总检复核','FAIL','关键项不合格 1 项（底盘），判定不合格','何总检',5,'2026-09-27 11:41:00');

-- 检测报告（5 份；含分项快照、不合格项、复检关联）
INSERT INTO `vc_report` (`id`,`report_no`,`task_id`,`plate_no`,`line_no`,`conclusion`,`conclusion_name`,`snapshot`,`fail_items`,`signer`,`sign_date`,`retest_of`,`create_time`) VALUES
 (1,'RPT-20260927-001',6,'京A·3M92X','L01','PASS','合格','外观:缺陷0项 合格 | 尾气:CO 0.090%/HC 21ppm 合格 | 制动:78.20% 合格 | 灯光:21500cd 合格 | 底盘:缺陷0项 合格','','授权签字人 何工','2026-09-27','','2026-09-27 10:19:00'),
 (2,'RPT-20260927-002',7,'京B·L2208挂','L02','PASS','合格','外观:缺陷1项 合格 | 尾气:CO 0.210%/HC 55ppm 合格 | 制动:69.10% 合格 | 灯光:19800cd 合格 | 底盘:缺陷0项 合格','','授权签字人 何工','2026-09-27','','2026-09-27 11:03:00'),
 (3,'RPT-20260927-003',8,'京A·W7710','L02','FAIL','不合格','外观:缺陷2项 合格 | 尾气:CO 0.480%/HC 96ppm 不合格 | 制动:71.20% 合格 | 灯光:17200cd 合格 | 底盘:制动管路渗漏 不合格','尾气 CO 超标;底盘 制动管路渗漏','授权签字人 何工','2026-09-27','','2026-09-27 11:27:00'),
 (4,'RPT-20260927-004',9,'京A·K339L','L02','FAIL','不合格','外观:缺陷3项 不合格 | 尾气:CO 0.150%/HC 38ppm 合格 | 制动:73.50% 合格 | 灯光:20400cd 合格 | 底盘:转向横拉杆球头松旷 不合格','外观 缺陷3项超限;底盘 转向横拉杆球头松旷','授权签字人 何工','2026-09-27','','2026-09-27 11:42:00'),
 (5,'RPT-20260926-005',6,'京A·3M92X','L01','PASS','合格','外观:缺陷0项 合格 | 尾气:CO 0.090%/HC 21ppm 合格 | 制动:78.20% 合格 | 灯光:21500cd 合格 | 底盘:缺陷0项 合格','','授权签字人 何工','2026-09-26','RPT-20260925-000','2026-09-26 16:20:00');

-- 设备台账（19 台；1-8 为 L01 在用（含超期、临期），9-13 属 L02，14-18 属 L04，19 属 L03）
INSERT INTO `vc_device` (`id`,`device_name`,`model`,`device_type`,`last_cal_date`,`next_cal_date`,`cal_org`,`cal_result`,`status`) VALUES
 (1,'尾气分析仪','MQW-511','EMISSION','2025-12-10','2026-09-20','省计量院','PASS','OVERDUE'),
 (2,'制动试验台','ZD-3000B','BRAKE','2026-03-15','2026-09-25','省计量院','PASS','OVERDUE'),
 (3,'灯光检测仪','NHD-8106','LIGHT','2026-06-20','2026-09-30','市计量所','PASS','DUE'),
 (4,'底盘测功机','DCG-2000','CHASSIS','2026-07-01','2026-10-05','省计量院','PASS','NORMAL'),
 (5,'外观查验终端','WG-PAD-12','APPEARANCE','2026-08-01','2026-11-01','站自校','PASS','NORMAL'),
 (6,'底盘间隙仪','JX-880','CHASSIS','2026-05-10','2026-09-29','市计量所','PASS','DUE'),
 (7,'OBD 诊断仪','OBD-900','EMISSION','2026-04-01','2026-10-15','厂家校准','PASS','NORMAL'),
 (8,'车速表检验台','CS-500','BRAKE','2026-02-01','2026-09-18','省计量院','FAIL','OVERDUE'),
 (9,'尾气分析仪B','MQW-512','EMISSION','2026-06-01','2026-12-01','省计量院','PASS','NORMAL'),
 (10,'制动试验台B','ZD-3000C','BRAKE','2026-05-15','2026-11-15','省计量院','PASS','NORMAL'),
 (11,'灯光检测仪B','NHD-8200','LIGHT','2026-04-20','2026-10-20','市计量所','PASS','NORMAL'),
 (12,'外观查验终端B','WG-PAD-13','APPEARANCE','2026-07-01','2027-01-01','站自校','PASS','NORMAL'),
 (13,'底盘间隙仪B','JX-880S','CHASSIS','2026-04-10','2026-10-08','市计量所','PASS','DUE'),
 (14,'尾气分析仪C','MQW-520','EMISSION','2026-06-10','2026-12-10','省计量院','PASS','NORMAL'),
 (15,'制动试验台C','ZD-3100','BRAKE','2026-05-30','2026-11-30','省计量院','PASS','NORMAL'),
 (16,'灯光检测仪C','NHD-8300','LIGHT','2026-04-25','2026-10-25','市计量所','PASS','NORMAL'),
 (17,'底盘测功机B','DCG-2100','CHASSIS','2026-05-20','2026-11-20','省计量院','PASS','NORMAL'),
 (18,'外观查验终端C','WG-PAD-14','APPEARANCE','2026-08-01','2027-02-01','站自校','PASS','NORMAL'),
 (19,'尾气分析仪（复检）','MQW-511R','EMISSION','2026-06-30','2026-12-31','省计量院','PASS','NORMAL');

-- 引车员（6 名）
INSERT INTO `vc_driver` (`id`,`driver_name`,`cert_level`,`cert_no`,`shift_hours`,`checked_count`,`status`) VALUES
 (1,'张引车','A1','YCY-2019-0117','8,9,10,11,12',4,'ON_DUTY'),
 (2,'李引车','A2','YCY-2020-0342','10,11,12,13,14',3,'ON_DUTY'),
 (3,'王引车','A1','YCY-2018-0058','13,14,15,16,17',2,'ON_DUTY'),
 (4,'赵引车','B2','YCY-2021-0719','8,9,10,14,15',5,'ON_DUTY'),
 (5,'孙引车','A2','YCY-2017-0923','15,16,17',4,'ON_DUTY'),
 (6,'周引车','C1','YCY-2022-0456','8,9,10,11',0,'OFF_DUTY');
