<template>
  <view class="page">
    <!-- 收货地址 -->
    <view class="section" @click="showAddressPicker = true">
      <view class="addr-card" v-if="selectedAddress">
        <view class="addr-top">
          <text class="addr-name">{{ selectedAddress.name }}</text>
          <text class="addr-phone">{{ selectedAddress.phone }}</text>
        </view>
        <text class="addr-detail">{{ selectedAddress.province }} {{ selectedAddress.city }} {{ selectedAddress.district }} {{ selectedAddress.detail }}</text>
      </view>
      <view class="no-addr" v-else>
        <text class="no-addr-text">+ 添加收货地址</text>
      </view>
    </view>

    <!-- 商品列表 -->
    <view class="section">
      <view class="item" v-for="item in cart" :key="item.id">
        <image :src="item.image" mode="aspectFill" class="item-img" />
        <view class="item-info">
          <text class="item-title">{{ item.title }}</text>
          <text class="item-qty">x{{ item.qty }}</text>
        </view>
        <text class="item-price">¥{{ (item.price * item.qty).toFixed(2) }}</text>
      </view>
    </view>

    <!-- 费用明细 -->
    <view class="section">
      <view class="fee-row">
        <text>商品金额</text>
        <text>¥{{ subtotal.toFixed(2) }}</text>
      </view>
      <view class="fee-row">
        <text>运费</text>
        <text>¥{{ shipping }}</text>
      </view>
      <view class="fee-row">
        <text>服务费</text>
        <text>¥{{ serviceFee.toFixed(2) }}</text>
      </view>
      <view class="fee-row total-row">
        <text>合计</text>
        <text class="total-price">¥{{ total.toFixed(2) }}</text>
      </view>
    </view>

    <!-- 提交 -->
    <view class="submit-btn" @click="doSubmit">提交订单 ¥{{ total.toFixed(2) }}</view>

    <!-- 地址选择器弹窗 -->
    <view class="picker-mask" v-if="showAddressPicker" @click="showAddressPicker = false">
      <view class="picker-panel" @click.stop>
        <text class="picker-title">选择收货地址</text>
        <scroll-view scroll-y class="picker-list">
          <view class="addr-option" v-for="a in addresses" :key="a.id" :class="{ selected: selectedAddress?.id === a.id }" @click="selectAddress(a)">
            <view class="addr-top"><text class="addr-name">{{ a.name }}</text><text class="addr-phone">{{ a.phone }}</text></view>
            <text class="addr-detail">{{ a.province }} {{ a.city }} {{ a.district }} {{ a.detail }}</text>
          </view>
          <view class="no-addr" v-if="!addresses.length">
            <text class="no-addr-text">暂无地址，请先去个人中心添加</text>
          </view>
        </scroll-view>
        <view class="picker-close" @click="showAddressPicker = false">关闭</view>
      </view>
    </view>
  </view>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue'
import { onShow } from '@dcloudio/uni-app'
import { getCart, getAddresses, createOrder, type CartItem } from '@/api'

const cart = ref<CartItem[]>([])
const addresses = ref<any[]>([])
const selectedAddress = ref<any>(null)
const showAddressPicker = ref(false)
const shipping = ref(20)

onShow(async () => {
  cart.value = getCart()
  if (!cart.value.length) {
    uni.showToast({ title: '购物车为空', icon: 'none' })
    setTimeout(() => uni.switchTab({ url: '/pages/cart/index' }), 800)
    return
  }
  // 加载地址
  const res = await getAddresses()
  if (res.success) {
    addresses.value = res.data || []
    if (addresses.value.length) selectedAddress.value = addresses.value[0]
  }
})

const subtotal = computed(() => cart.value.reduce((s, i) => s + i.price * i.qty, 0))
const serviceFee = computed(() => Math.round(subtotal.value * 0.1 * 100) / 100)
const total = computed(() => subtotal.value + shipping.value + serviceFee.value)

function selectAddress(a: any) {
  selectedAddress.value = a
  showAddressPicker.value = false
}

async function doSubmit() {
  if (!selectedAddress.value) {
    uni.showToast({ title: '请选择收货地址', icon: 'none' })
    return
  }
  uni.showLoading({ title: '提交中' })
  try {
    const res = await createOrder({
      items: cart.value.map(i => ({ product_id: i.id, qty: i.qty, price: i.price })),
      address_id: selectedAddress.value.id,
      shipping: shipping.value,
      service_fee: serviceFee.value
    })
    uni.hideLoading()
    if (res.success) {
      // 清空购物车
      uni.removeStorageSync('like_art_cart')
      const payUrl = res.data.pay_url || ''
      if (payUrl) {
        // 跳转支付
        window.location.href = payUrl
      } else {
        uni.showToast({ title: '下单成功' })
        setTimeout(() => uni.switchTab({ url: '/pages/orders/index' }), 1000)
      }
    } else {
      uni.showToast({ title: res.message || '下单失败', icon: 'none' })
    }
  } catch (e) {
    uni.hideLoading()
    uni.showToast({ title: '网络错误', icon: 'none' })
  }
}
</script>

<style>
.page { background: #f5f5f5; min-height: 100vh; padding-bottom: 120rpx; }

.section { background: #fff; margin: 16rpx 24rpx; border-radius: 16rpx; padding: 24rpx; }
.addr-card { }
.addr-top { display: flex; gap: 16rpx; margin-bottom: 8rpx; }
.addr-name { font-size: 30rpx; font-weight: bold; color: #333; }
.addr-phone { font-size: 28rpx; color: #666; }
.addr-detail { font-size: 26rpx; color: #999; }
.no-addr { text-align: center; padding: 32rpx; }
.no-addr-text { font-size: 28rpx; color: #8B9E87; }

.item { display: flex; align-items: center; padding: 16rpx 0; border-bottom: 1rpx solid #f5f5f5; }
.item:last-child { border-bottom: none; }
.item-img { width: 100rpx; height: 100rpx; border-radius: 8rpx; flex-shrink: 0; }
.item-info { flex: 1; margin-left: 16rpx; }
.item-title { display: block; font-size: 26rpx; color: #333; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.item-qty { font-size: 24rpx; color: #999; margin-top: 4rpx; }
.item-price { font-size: 28rpx; color: #e74c3c; font-weight: bold; }

.fee-row { display: flex; justify-content: space-between; padding: 12rpx 0; font-size: 28rpx; color: #666; }
.total-row { border-top: 1rpx solid #f0f0f0; padding-top: 16rpx; margin-top: 8rpx; }
.total-price { font-size: 36rpx; font-weight: bold; color: #e74c3c; }

.submit-btn { position: fixed; bottom: 0; left: 0; right: 0; height: 100rpx; line-height: 100rpx; text-align: center; background: #8B9E87; color: #fff; font-size: 32rpx; padding-bottom: env(safe-area-inset-bottom); }

.picker-mask { position: fixed; top: 0; left: 0; right: 0; bottom: 0; background: rgba(0,0,0,.5); z-index: 999; display: flex; align-items: flex-end; }
.picker-panel { background: #fff; border-radius: 24rpx 24rpx 0 0; width: 100%; max-height: 60vh; display: flex; flex-direction: column; }
.picker-title { font-size: 32rpx; font-weight: bold; text-align: center; padding: 24rpx; }
.picker-list { flex: 1; max-height: 40vh; }
.addr-option { padding: 24rpx; border-bottom: 1rpx solid #f5f5f5; }
.addr-option.selected { background: #f0f8f0; }
.picker-close { text-align: center; padding: 24rpx; color: #999; font-size: 28rpx; border-top: 1rpx solid #f0f0f0; }
</style>
