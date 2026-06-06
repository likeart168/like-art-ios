<template>
  <view class="page">
    <!-- 空购物车 -->
    <view class="empty" v-if="!cart.length">
      <text class="empty-icon">🛒</text>
      <text class="empty-text">购物车是空的</text>
      <text class="empty-btn" @click="goShop">去逛逛</text>
    </view>

    <!-- 购物车列表 -->
    <template v-else>
      <view class="list">
        <view class="item" v-for="item in cart" :key="item.id">
          <image :src="item.image" mode="aspectFill" class="item-img" @click="goDetail(item.id)" />
          <view class="item-info">
            <text class="item-title">{{ item.title }}</text>
            <text class="item-price">¥{{ item.price }}</text>
            <view class="qty-row">
              <text class="qty-btn" @click="changeQty(item.id, -1)">−</text>
              <text class="qty-num">{{ item.qty }}</text>
              <text class="qty-btn" @click="changeQty(item.id, 1)">+</text>
            </view>
          </view>
          <text class="del-btn" @click="removeItem(item.id)">删除</text>
        </view>
      </view>

      <!-- 底部结算栏 -->
      <view class="footer">
        <view class="total">
          <text class="total-label">合计：</text>
          <text class="total-price">¥{{ totalPrice }}</text>
        </view>
        <view class="checkout-btn" @click="goCheckout">去结算 ({{ totalQty }})</view>
      </view>
    </template>
  </view>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue'
import { onShow } from '@dcloudio/uni-app'
import { getCart, saveCart, removeFromCart, type CartItem } from '@/api'

const cart = ref<CartItem[]>([])

onShow(() => {
  cart.value = getCart()
})

const totalPrice = computed(() => {
  return cart.value.reduce((sum, i) => sum + (i.price || 0) * (i.qty || 1), 0).toFixed(2)
})
const totalQty = computed(() => {
  return cart.value.reduce((sum, i) => sum + (i.qty || 1), 0)
})

function changeQty(id: number, delta: number) {
  const idx = cart.value.findIndex(i => i.id === id)
  if (idx < 0) return
  cart.value[idx].qty = Math.max(1, (cart.value[idx].qty || 1) + delta)
  saveCart(cart.value)
}

function removeItem(id: number) {
  uni.showModal({
    title: '确认删除',
    content: '确定要移除此商品吗？',
    success: (res) => {
      if (res.confirm) {
        cart.value = removeFromCart(id)
      }
    }
  })
}

function goDetail(id: number) { uni.navigateTo({ url: `/pages/product/index?id=${id}` }) }
function goShop() { uni.switchTab({ url: '/pages/products/index' }) }
function goCheckout() {
  const token = uni.getStorageSync('token')
  if (!token) {
    uni.showToast({ title: '请先登录', icon: 'none' })
    setTimeout(() => uni.navigateTo({ url: '/pages/login/index' }), 800)
    return
  }
  uni.navigateTo({ url: '/pages/checkout/index' })
}
</script>

<style>
.page { background: #f5f5f5; min-height: 100vh; display: flex; flex-direction: column; }

.empty { flex: 1; display: flex; flex-direction: column; align-items: center; justify-content: center; }
.empty-icon { font-size: 100rpx; margin-bottom: 24rpx; }
.empty-text { font-size: 30rpx; color: #999; margin-bottom: 32rpx; }
.empty-btn { padding: 16rpx 48rpx; background: #8B9E87; color: #fff; border-radius: 40rpx; font-size: 28rpx; }

.list { flex: 1; padding: 16rpx 24rpx; }
.item { display: flex; background: #fff; border-radius: 16rpx; padding: 20rpx; margin-bottom: 16rpx; align-items: center; }
.item-img { width: 160rpx; height: 160rpx; border-radius: 12rpx; flex-shrink: 0; }
.item-info { flex: 1; margin-left: 20rpx; }
.item-title { display: block; font-size: 28rpx; color: #333; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.item-price { display: block; font-size: 34rpx; font-weight: bold; color: #e74c3c; margin-top: 8rpx; }
.qty-row { display: flex; align-items: center; margin-top: 12rpx; }
.qty-btn { width: 48rpx; height: 48rpx; line-height: 48rpx; text-align: center; border: 2rpx solid #e0e0e0; border-radius: 8rpx; font-size: 28rpx; color: #666; }
.qty-num { width: 60rpx; text-align: center; font-size: 28rpx; }
.del-btn { font-size: 24rpx; color: #ccc; margin-left: 16rpx; }

.footer { display: flex; align-items: center; justify-content: space-between; padding: 20rpx 24rpx; background: #fff; border-top: 1rpx solid #f0f0f0; padding-bottom: calc(20rpx + env(safe-area-inset-bottom)); }
.total-label { font-size: 28rpx; color: #333; }
.total-price { font-size: 38rpx; font-weight: bold; color: #e74c3c; }
.checkout-btn { padding: 20rpx 40rpx; background: #8B9E87; color: #fff; border-radius: 40rpx; font-size: 28rpx; }
</style>
