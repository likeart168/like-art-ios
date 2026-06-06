<template>
  <view class="page">
    <!-- 状态Tab -->
    <view class="tabs">
      <text class="tab" :class="{ active: status === '' }" @click="status = ''; fetchOrders()">全部</text>
      <text class="tab" :class="{ active: status === 'pending' }" @click="status = 'pending'; fetchOrders()">待付款</text>
      <text class="tab" :class="{ active: status === 'paid' }" @click="status = 'paid'; fetchOrders()">已付款</text>
      <text class="tab" :class="{ active: status === 'shipped' }" @click="status = 'shipped'; fetchOrders()">已发货</text>
      <text class="tab" :class="{ active: status === 'completed' }" @click="status = 'completed'; fetchOrders()">已完成</text>
    </view>

    <view class="empty" v-if="!orders.length">
      <text class="empty-icon">📦</text>
      <text class="empty-text">暂无订单</text>
    </view>

    <view class="list">
      <view class="order" v-for="o in orders" :key="o.id">
        <view class="order-hd">
          <text class="order-no">{{ o.order_no || o.id }}</text>
          <text class="order-status" :style="{ color: statusColor(o.status) }">{{ statusText(o.status) }}</text>
        </view>
        <view class="order-items">
          <view class="o-item" v-for="item in (o.items || [])" :key="item.id">
            <image :src="item.image || ''" mode="aspectFill" class="o-img" />
            <view class="o-info">
              <text class="o-title">{{ item.title }}</text>
              <text class="o-qty">x{{ item.qty }}</text>
            </view>
            <text class="o-price">¥{{ item.price }}</text>
          </view>
        </view>
        <view class="order-footer">
          <text class="order-total">共{{ o.items?.length || 1 }}件 合计：<text class="order-total-price">¥{{ o.total_amount }}</text></text>
          <view class="order-actions">
            <text class="o-btn" v-if="o.status === 'pending'" @click="goPay(o)">去支付</text>
            <text class="o-btn" @click="goDetail(o.id)">查看详情</text>
          </view>
        </view>
      </view>
    </view>
  </view>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { getOrders } from '@/api'

const status = ref('')
const orders = ref<any[]>([])

onMounted(() => fetchOrders())

async function fetchOrders() {
  const token = uni.getStorageSync('token')
  if (!token) {
    uni.showToast({ title: '请先登录', icon: 'none' })
    return
  }
  uni.showLoading({ title: '加载中' })
  try {
    const params: any = {}
    if (status.value) params.status = status.value
    const res = await getOrders(params)
    if (res.success) {
      orders.value = res.data.orders || res.data || []
    }
  } catch (e) {}
  uni.hideLoading()
}

function statusText(s: string) {
  const map: any = { pending: '待付款', paid: '已付款', shipped: '已发货', completed: '已完成', cancelled: '已取消', refunded: '已退款' }
  return map[s] || s
}
function statusColor(s: string) {
  const map: any = { pending: '#e74c3c', paid: '#f39c12', shipped: '#3498db', completed: '#27ae60', cancelled: '#999' }
  return map[s] || '#999'
}
function goPay(o: any) {
  uni.showToast({ title: '支付功能开发中', icon: 'none' })
}
function goDetail(id: number) {
  uni.showToast({ title: '订单详情开发中', icon: 'none' })
}
</script>

<style>
.page { background: #f5f5f5; min-height: 100vh; }
.tabs { display: flex; background: #fff; padding: 0 8rpx; }
.tab { flex: 1; text-align: center; padding: 24rpx 0; font-size: 26rpx; color: #666; }
.tab.active { color: #8B9E87; font-weight: bold; border-bottom: 4rpx solid #8B9E87; }

.empty { display: flex; flex-direction: column; align-items: center; padding: 120rpx 0; }
.empty-icon { font-size: 80rpx; margin-bottom: 16rpx; }
.empty-text { font-size: 28rpx; color: #ccc; }

.list { padding: 16rpx 24rpx; }
.order { background: #fff; border-radius: 16rpx; margin-bottom: 16rpx; overflow: hidden; }
.order-hd { display: flex; justify-content: space-between; padding: 20rpx 24rpx; border-bottom: 1rpx solid #f5f5f5; }
.order-no { font-size: 24rpx; color: #999; }
.order-status { font-size: 24rpx; }

.o-item { display: flex; align-items: center; padding: 16rpx 24rpx; }
.o-img { width: 100rpx; height: 100rpx; border-radius: 8rpx; flex-shrink: 0; background: #f0f0f0; }
.o-info { flex: 1; margin-left: 16rpx; }
.o-title { display: block; font-size: 26rpx; color: #333; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.o-qty { font-size: 24rpx; color: #999; }
.o-price { font-size: 28rpx; color: #e74c3c; }

.order-footer { display: flex; justify-content: space-between; align-items: center; padding: 16rpx 24rpx; border-top: 1rpx solid #f5f5f5; }
.order-total { font-size: 24rpx; color: #666; }
.order-total-price { color: #e74c3c; }
.order-actions { display: flex; gap: 12rpx; }
.o-btn { padding: 10rpx 24rpx; border: 2rpx solid #8B9E87; border-radius: 24rpx; font-size: 24rpx; color: #8B9E87; }
</style>
