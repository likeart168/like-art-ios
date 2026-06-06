<template>
  <view class="page">
    <view class="empty" v-if="!auctions.length">
      <text class="empty-icon">🔨</text>
      <text class="empty-text">暂无拍卖中的作品</text>
    </view>

    <view class="list">
      <view class="card" v-for="a in auctions" :key="a.id">
        <image :src="a.image" mode="aspectFill" class="card-img" />
        <view class="card-info">
          <text class="card-title">{{ a.title }}</text>
          <view class="price-row">
            <view class="price-col">
              <text class="label">当前出价</text>
              <text class="current-price">¥{{ a.current_price || a.start_price }}</text>
            </view>
            <view class="price-col">
              <text class="label">起拍价</text>
              <text class="start-price">¥{{ a.start_price }}</text>
            </view>
          </view>
          <view class="bid-row">
            <text class="bid-count">{{ a.bids_count || 0 }} 次出价</text>
            <text class="time-left" v-if="a.end_time">{{ countdown(a.end_time) }}</text>
          </view>
          <!-- 出价 -->
          <view class="bid-input-row">
            <input class="bid-input" v-model="bidAmounts[a.id]" type="digit" :placeholder="'最低 ¥' + (a.min_next_bid || a.current_price || a.start_price)" />
            <view class="btn-bid" @click="doBid(a)">出价</view>
          </view>
        </view>
      </view>
    </view>
  </view>
</template>

<script setup lang="ts">
import { ref, reactive, onMounted } from 'vue'
import { getAuctions, placeBid } from '@/api'

const auctions = ref<any[]>([])
const bidAmounts = reactive<Record<number, string>>({})

onMounted(async () => {
  uni.showLoading({ title: '加载中' })
  try {
    const res = await getAuctions()
    if (res.success) {
      auctions.value = (res.data.auctions || res.data || []).map((a: any) => ({
        id: a.id,
        title: a.title_zh || a.title || '',
        image: a.images ? (typeof a.images === 'string' ? JSON.parse(a.images)[0] : a.images[0]) : '',
        start_price: a.start_price || 0,
        current_price: a.current_price || a.start_price || 0,
        min_next_bid: a.current_price ? a.current_price + 10 : (a.start_price || 0),
        bids_count: a.bids_count || 0,
        end_time: a.end_time
      }))
    }
  } catch (e) {}
  uni.hideLoading()
})

function countdown(endTime: string) {
  const diff = new Date(endTime).getTime() - Date.now()
  if (diff <= 0) return '已结束'
  const m = Math.floor(diff / 60000)
  const s = Math.floor((diff % 60000) / 1000)
  return `${m}:${s.toString().padStart(2, '0')}`
}

async function doBid(a: any) {
  const amount = parseFloat(bidAmounts[a.id] || '')
  const minBid = a.min_next_bid || a.current_price || a.start_price
  if (!amount || amount < minBid) {
    uni.showToast({ title: `出价不能低于 ¥${minBid}`, icon: 'none' })
    return
  }
  const token = uni.getStorageSync('token')
  if (!token) {
    uni.showToast({ title: '请先登录', icon: 'none' })
    return
  }
  uni.showLoading({ title: '出价中' })
  const res = await placeBid(a.id, amount)
  uni.hideLoading()
  if (res.success) {
    uni.showToast({ title: '出价成功！', icon: 'success' })
    a.current_price = amount
    a.bids_count = (a.bids_count || 0) + 1
    a.min_next_bid = amount + 10
    bidAmounts[a.id] = ''
  } else {
    uni.showToast({ title: res.message || '出价失败', icon: 'none' })
  }
}
</script>

<style>
.page { background: #f5f5f5; min-height: 100vh; padding-bottom: 40rpx; }

.empty { display: flex; flex-direction: column; align-items: center; padding: 120rpx 0; }
.empty-icon { font-size: 80rpx; margin-bottom: 16rpx; }
.empty-text { font-size: 28rpx; color: #ccc; }

.list { padding: 16rpx 24rpx; display: flex; flex-direction: column; gap: 16rpx; }
.card { background: #fff; border-radius: 16rpx; overflow: hidden; }
.card-img { width: 100%; height: 400rpx; }
.card-info { padding: 20rpx 24rpx; }

.card-title { font-size: 32rpx; font-weight: bold; color: #333; display: block; margin-bottom: 16rpx; }

.price-row { display: flex; gap: 32rpx; margin-bottom: 12rpx; }
.price-col { }
.label { display: block; font-size: 22rpx; color: #999; margin-bottom: 4rpx; }
.current-price { font-size: 36rpx; font-weight: bold; color: #e74c3c; }
.start-price { font-size: 30rpx; color: #999; }

.bid-row { display: flex; justify-content: space-between; margin-bottom: 16rpx; }
.bid-count { font-size: 24rpx; color: #999; }
.time-left { font-size: 24rpx; color: #e74c3c; }

.bid-input-row { display: flex; gap: 16rpx; align-items: center; }
.bid-input { flex: 1; height: 72rpx; border: 2rpx solid #e0e0e0; border-radius: 12rpx; padding: 0 20rpx; font-size: 28rpx; }
.btn-bid { padding: 16rpx 36rpx; background: #e74c3c; color: #fff; border-radius: 12rpx; font-size: 28rpx; white-space: nowrap; }
</style>
