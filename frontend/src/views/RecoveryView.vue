<template>
  <div class="vc-grid" style="grid-template-columns: 400px 1fr;">
    <!-- 左：受故障工位影响的在检车辆 -->
    <section class="vc-card">
      <div class="vc-card-title">
        待处置车辆（工位故障）
        <el-tag size="small" :type="affected.length ? 'danger' : 'success'" effect="dark">
          {{ affected.length }} 辆
        </el-tag>
        <el-button size="small" style="margin-left: auto;" @click="loadAll">刷新</el-button>
      </div>

      <el-scrollbar max-height="600px">
        <div
          v-for="t in affected"
          :key="t.taskId"
          class="vc-af-item"
          :class="{ active: selected && selected.taskId === t.taskId }"
          @click="selectTask(t)"
        >
          <div class="vc-af-head">
            <span class="vc-af-plate">{{ t.plateNo }}</span>
            <el-tag size="small" :type="t.status === 'RETEST' ? 'warning' : 'primary'">
              {{ t.statusName }}
            </el-tag>
          </div>
          <div class="vc-muted vc-af-meta">
            {{ t.taskNo }} ｜ {{ t.ownerName }} ｜ {{ t.vehicleTypeName }}
          </div>
          <div class="vc-af-fault">
            卡在 {{ t.lineNo }} 第 {{ t.currentSeqNo }} 工位 · {{ t.faultStationName }}（故障）
          </div>
          <div class="vc-af-progress">
            <span>已完成：{{ t.doneStations.length ? t.doneStations.join('、') : '无' }}</span>
            <span>待继续：{{ t.remainingStations.join('、') }}</span>
          </div>
          <div class="vc-af-foot">
            <el-tag v-if="t.failRecordCount > 0" size="small" type="danger" effect="plain">
              已有 {{ t.failRecordCount }} 条不合格记录，转线保留
            </el-tag>
            <el-tag v-if="t.originReportNo" size="small" type="warning" effect="plain">
              复检关联 {{ t.originReportNo }}
            </el-tag>
          </div>
        </div>
        <el-empty v-if="!affected.length" description="暂无待处置车辆：故障工位上没有在检车辆" :image-size="60" />
      </el-scrollbar>
    </section>

    <!-- 右：候选检测线 + 处置记录 -->
    <section style="display: grid; gap: 14px; grid-template-rows: auto auto 1fr; align-content: start;">
      <div class="vc-card">
        <div class="vc-card-title">
          候选检测线评估
          <span v-if="selected" class="vc-muted" style="font-weight: 400; font-size: 12px;">
            {{ selected.plateNo }} · {{ selected.vehicleTypeName }} · 剩余 {{ selected.remainingStations.join('→') }}
          </span>
          <el-button v-if="selected" size="small" style="margin-left: auto;" @click="loadCandidates">
            重新评估
          </el-button>
        </div>

        <template v-if="selected">
          <el-alert
            v-if="!availableCount"
            type="warning"
            :closable="false"
            show-icon
            style="margin-bottom: 10px;"
            title="暂无可用目标线：车辆保持待处置并保留故障前进度，故障解除后可回原线继续"
          />
          <div
            v-for="c in candidates"
            :key="c.lineId"
            class="vc-cand"
            :class="{ ok: c.available, no: !c.available }"
          >
            <div class="vc-cand-main">
              <div class="vc-cand-head">
                <b>{{ c.lineNo }} · {{ c.lineName }}</b>
                <el-tag size="small" effect="plain">{{ c.lineTypeName }}</el-tag>
                <el-tag v-if="c.recommended" size="small" type="success" effect="dark">推荐</el-tag>
                <el-tag v-else-if="c.available" size="small" type="success" effect="plain">可转入</el-tag>
                <el-tag v-else size="small" type="danger" effect="plain">排除</el-tag>
              </div>
              <div class="vc-muted" style="font-size: 12px; margin-top: 2px;">
                承接车型：{{ c.acceptTypeNames.length ? c.acceptTypeNames.join('、') : '无' }}
                <template v-if="c.resumeStationId">
                  ｜ 目标工位：{{ c.resumeStationName }}（{{ c.resumeStationStatusName }}）
                  ｜ 排队 {{ c.resumeQueue }} 辆 · 剩余工位在检 {{ c.remainingLoad }} 辆
                </template>
              </div>
              <ul class="vc-cand-reasons">
                <li v-for="(r, i) in c.reasons" :key="i" :class="c.available ? 'ok' : 'no'">
                  {{ c.available ? '✓' : '✕' }} {{ r }}
                </li>
              </ul>
            </div>
            <el-button
              v-if="c.available"
              type="primary"
              size="small"
              class="vc-cand-btn"
              @click="openConfirm(c)"
            >
              确认转线
            </el-button>
          </div>
        </template>
        <el-empty v-else description="请先在左侧选择一辆待处置车辆" :image-size="60" />
      </div>

      <div class="vc-card">
        <div class="vc-card-title">
          处置记录台账
          <span class="vc-muted" style="font-weight: 400; font-size: 12px;">
            任务、流水线进度与最终报告共用同一份连续检测链
          </span>
        </div>
        <el-table :data="records" size="small" height="220">
          <el-table-column prop="plateNo" label="车牌" width="110" />
          <el-table-column prop="taskNo" label="任务号" width="160" />
          <el-table-column label="跨线轨迹" min-width="200">
            <template #default="{ row }">
              {{ row.fromLineNo }} · {{ row.fromStationName }}
              <span class="vc-transfer-arrow">→</span>
              {{ row.toLineNo }} · {{ row.toStationName }}
              <span class="vc-muted">（第 {{ row.seqNo }} 工位）</span>
            </template>
          </el-table-column>
          <el-table-column prop="operatorName" label="值班员" width="90" />
          <el-table-column prop="reason" label="处置原因" min-width="160" show-overflow-tooltip />
          <el-table-column label="时间" width="150">
            <template #default="{ row }">
              {{ row.createTime ? String(row.createTime).replace('T', ' ') : '' }}
            </template>
          </el-table-column>
          <template #empty>暂无跨线处置记录</template>
        </el-table>
      </div>
    </section>
  </div>

  <!-- 确认转线 -->
  <el-dialog v-model="confirmVisible" title="确认跨线恢复" width="520px">
    <el-alert type="warning" :closable="false" show-icon style="margin-bottom: 12px;">
      <div>
        车辆 <b>{{ selected?.plateNo }}</b> 将从
        <b>{{ selected?.lineNo }} · {{ selected?.faultStationName }}</b>（故障）转往
        <b>{{ target?.lineNo }} · {{ target?.resumeStationName }}</b>，从第 {{ selected?.currentSeqNo }} 工位继续。
      </div>
      <div style="margin-top: 6px;">
        已完成 {{ selected?.doneStations.length || 0 }} 个工位的结果与操作痕迹原样保留，
        <template v-if="selected?.failRecordCount > 0">
          含 {{ selected.failRecordCount }} 条不合格记录，不会因换线被清洗；
        </template>
        剩余工位在目标线按原顺序继续，报告沿用同一份连续检测链。
      </div>
    </el-alert>
    <el-form label-width="90px">
      <el-form-item label="值班员">
        <el-input v-model="confirmForm.operatorName" placeholder="值班人员姓名" />
      </el-form-item>
      <el-form-item label="处置原因">
        <el-input
          v-model="confirmForm.reason"
          type="textarea"
          :rows="2"
          :placeholder="selected ? selected.faultStationName + '工位故障，跨线恢复' : '工位故障，跨线恢复'"
        />
      </el-form-item>
    </el-form>
    <template #footer>
      <el-button @click="confirmVisible = false">取消</el-button>
      <el-button type="primary" :loading="confirming" @click="submitConfirm">确认转线</el-button>
    </template>
  </el-dialog>
</template>

<script setup>
import { computed, inject, onMounted, onUnmounted, reactive, ref } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import { fetchAffected, fetchCandidates, confirmTransfer, fetchTransferRecords } from '../api'

const pipeline = inject('pipeline', null)

const affected = ref([])
const candidates = ref([])
const records = ref([])
const selected = ref(null)
const target = ref(null)
const confirmVisible = ref(false)
const confirming = ref(false)
const confirmForm = reactive({ operatorName: '', reason: '' })

const availableCount = computed(() => candidates.value.filter((c) => c.available).length)

let timer = null

async function loadAffected () {
  const list = await fetchAffected()
  affected.value = list
  if (selected.value) {
    // 选中车辆可能已被其他值班员处置：同步最新去向，避免页面停留在过期快照
    const still = list.find((t) => t.taskId === selected.value.taskId)
    selected.value = still || null
    if (!still) {
      candidates.value = []
    }
  }
}

async function loadCandidates () {
  if (!selected.value) return
  candidates.value = await fetchCandidates(selected.value.taskId)
}

async function loadRecords () {
  records.value = await fetchTransferRecords()
}

async function loadAll () {
  try {
    await loadAffected()
    await Promise.all([loadCandidates(), loadRecords()])
  } catch (e) {
    ElMessage.error(e.message)
  }
}

async function selectTask (t) {
  selected.value = t
  try {
    await loadCandidates()
  } catch (e) {
    ElMessage.error(e.message)
  }
}

function openConfirm (c) {
  target.value = c
  confirmForm.reason = ''
  confirmVisible.value = true
}

async function submitConfirm () {
  if (!selected.value || !target.value) return
  confirming.value = true
  try {
    const result = await confirmTransfer(selected.value.taskId, {
      toLineId: target.value.lineId,
      operatorName: confirmForm.operatorName,
      reason: confirmForm.reason
    })
    confirmVisible.value = false
    ElMessage.success(
      `跨线恢复成功：${result.record.plateNo} 已转往 ${result.record.toLineNo} · ${result.record.toStationName}工位，` +
      `已完成工位结果与不合格记录原样保留`
    )
    await loadAll()
    // 底部流水线徽章与顶部 KPI 同步刷新（状态回写后的页面展示一并更新）
    pipeline?.reload?.()
    if (result.task) {
      pipeline?.moveCapsule?.(result.task.plateNo, result.task.currentSeqNo)
    }
  } catch (e) {
    confirmVisible.value = false
    // 并发冲突 / 目标工位被抢占：展示后端返回的最新去向，并刷新列表
    ElMessageBox.alert(e.message, '转线未生效', { type: 'warning', confirmButtonText: '知道了' })
    await loadAll()
    pipeline?.reload?.()
  } finally {
    confirming.value = false
  }
}

onMounted(async () => {
  await loadAll()
  timer = setInterval(async () => {
    try {
      await loadAffected()
      await loadRecords()
      if (selected.value) await loadCandidates()
    } catch (e) {
      // 轮询失败不打断页面
    }
  }, 15000)
})

onUnmounted(() => {
  if (timer) clearInterval(timer)
})
</script>

<style scoped>
.vc-af-item {
  border: 1px solid var(--vc-border);
  border-radius: 6px;
  padding: 10px 12px;
  margin-bottom: 10px;
  cursor: pointer;
  transition: all 0.18s ease;
}

.vc-af-item:hover {
  border-color: var(--vc-primary);
  background: #f5f9fd;
}

.vc-af-item.active {
  border-color: var(--vc-primary);
  background: #eaf2fa;
  box-shadow: inset 3px 0 0 var(--vc-primary);
}

.vc-af-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
}

.vc-af-plate {
  font-size: 16px;
  font-weight: 700;
  color: var(--vc-primary-deep);
}

.vc-af-meta {
  font-size: 12px;
  margin-top: 2px;
}

.vc-af-fault {
  margin-top: 6px;
  font-size: 12px;
  color: var(--vc-fail);
  font-weight: 600;
}

.vc-af-progress {
  margin-top: 4px;
  display: flex;
  flex-direction: column;
  gap: 2px;
  font-size: 12px;
  color: #54677d;
}

.vc-af-foot {
  margin-top: 6px;
  display: flex;
  gap: 6px;
  flex-wrap: wrap;
}

.vc-cand {
  display: flex;
  align-items: flex-start;
  gap: 12px;
  border: 1px solid var(--vc-border);
  border-radius: 8px;
  padding: 10px 14px;
  margin-bottom: 10px;
}

.vc-cand.ok {
  border-color: #b7e2c9;
  background: #f6fcf8;
}

.vc-cand.no {
  background: #fdf7f6;
  opacity: 0.92;
}

.vc-cand-main {
  flex: 1 1 auto;
  min-width: 0;
}

.vc-cand-head {
  display: flex;
  align-items: center;
  gap: 8px;
}

.vc-cand-reasons {
  margin: 6px 0 0;
  padding: 0;
  list-style: none;
  font-size: 12px;
}

.vc-cand-reasons li {
  padding: 1px 0;
}

.vc-cand-reasons li.ok {
  color: var(--vc-pass);
}

.vc-cand-reasons li.no {
  color: var(--vc-fail);
}

.vc-cand-btn {
  flex: 0 0 auto;
  margin-top: 4px;
}

.vc-transfer-arrow {
  color: var(--vc-primary);
  font-weight: 700;
  margin: 0 4px;
}
</style>
