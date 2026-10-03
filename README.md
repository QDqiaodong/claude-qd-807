# 机动车检测站 · 工位与检测报告管理

以「检测线工位流水 + 检测报告」为核心的机动车年检 / 安检站管理系统。

## 端口

| 服务 | 端口 |
| --- | --- |
| 前端 (Vue 3 + Element Plus) | 8287 |
| 后端 (Spring Boot 3.3.0 / Java 17) | 8387 |
| MySQL 8 | 3587 |
| Redis | 6587 |

## 启动 / 停止

```bash
./start.sh            # 首次或 --build 时构建，镜像已存在则秒起
docker compose logs -f backend
./stop.sh             # 停止
./resume.sh           # 恢复
./clean.sh            # down -v（必须带 -v，清掉 mysql 匿名卷）
./nuke.sh             # 彻底清理
```

## 模块

1. **检测线与工位** — 线号、类型（安检 / 环保 / 综检）、状态（运行 / 停用）、可承接车型；工位按 登录 → 外观 → 尾气 → 制动 → 灯光 → 底盘 → 总检 顺序流转。
2. **车辆与送检** — 车牌、车主、车辆类型（小型客车 / 货车 / 危化品车）、注册日期、里程、燃料类型、送检人、预约时间。
3. **检测任务与工位流转** — 各工位结果值（尾气 CO/HC、制动率、灯光强度、底盘缺陷项），任务状态 在检 / 合格 / 不合格 / 复检。
4. **检测报告** — 报告编号、判定结论、各分项结果快照、不合格项、签发人、签发日期、复检关联。
5. **设备标定与引车员** — 设备台账与下次标定倒计时；引车员资质、当日排班小时段、已检台次。
6. **跨线恢复处置台** — 工位故障后，受影响在检车辆一览；按「剩余工位顺序一致 + 车型承接 + 标定有效」硬条件评估候选线并逐条展示推荐 / 排除原因，负载只在可用线之间排序；确认转线单事务完成目标工位占位、任务迁移、旧工位释放与处置记录，已完成结果与不合格项原样保留，报告沿用同一份连续检测链。

## 数据访问技术标识：`@ColumnTransformer`

| 列 | 库内 | 实体 / 接口 |
| --- | --- | --- |
| `vc_vehicle.owner_id_no` | `AES_ENCRYPT(?, 'seed_key')` 的 VARBINARY 密文 | 明文字符串 |
| `vc_vehicle.owner_phone` | 同上 | 明文字符串 |
| `vc_task.brake_rate` | 小数 `0.6230` | 百分比 `62.30` |

读取表达式：

```java
@ColumnTransformer(
    read = "CONVERT(AES_DECRYPT(owner_id_no, 'seed_key') USING utf8mb4)",
    write = "AES_ENCRYPT(?, 'seed_key')")
private String ownerIdNo;

@ColumnTransformer(read = "brake_rate * 100", write = "? / 100")
private BigDecimal brakeRate;
```

## 手写 JPQL（`@Query`）

- `TaskStationRecordRepository.statPassRateByStation` — 按工位统计通过率
- `TaskStationRecordRepository.rankFailItems` — 不合格项排行
- `TaskRepository.countGroupByDriverAndDate` — 按引车员统计当日台次
- `TaskRepository.countQueueGroupByStation` — 各工位排队车辆数（底部流水线徽章）
- `ReportRepository.statReportByLine` — 按检测线统计报告数与不合格数
- `DeviceRepository.statCalibration` / `findDevicesOfLine` — 标定状态统计与按线取设备

## 业务规则（service 层抛 `BizException`）

- 工位必须按顺序流转：未完成前序工位不允许进入下一工位，提示卡在第几个工位。
- 任一关键项（尾气 / 制动 / 灯光 / 底盘）不合格，报告结论必须为不合格。
- 设备超过标定日期不允许签发报告，提示超期天数。
- 同一车辆当天重复建档送检会被拦截。
- 故障工位禁止继续录入检测值；车辆保持待处置，可跨线转走或待故障解除后回原线继续。
- 跨线恢复并发口径：目标工位 CAS 占位 + 任务 CAS 迁移，两名值班员同时处置同一车辆只允许一次成功，失败方看到最新去向，事务整体回滚不留半迁移。

## 前端

底部固定「流水线进度条导航」：登录 → 外观 → 尾气 → 制动 → 灯光 → 底盘 → 总检，节点上方显示排队车辆数徽章，
一枚「当前车辆」胶囊沿节点移动（CSS 过渡动画）。五个页面分别为工位流水线、报告预览 + 判定徽章墙、
引车员排班格子表、设备标定倒计时卡、跨线恢复处置台。主色 `#01579b`。
