<template>
  <view class="page">
    <!-- 未登录 -->
    <template v-if="!isLogin">
      <view class="login-area">
        <image class="avatar-placeholder" src="/static/logo.png" mode="aspectFit" />
        <text class="login-tip" @click="goLogin">点击登录</text>
      </view>
    </template>

    <!-- 已登录 -->
    <template v-else>
      <view class="user-area">
        <image class="avatar" :src="user.avatar || '/static/logo.png'" mode="aspectFill" @click="uploadAvatar" />
        <view class="user-info">
          <text class="user-name">{{ user.name || '用户' + user.user_code }}</text>
          <text class="user-code">{{ user.user_code }}</text>
        </view>
      </view>
    </template>

    <!-- 菜单 -->
    <view class="menu-section">
      <view class="menu-item" @click="goOrders">
        <text class="menu-icon">📦</text>
        <text class="menu-text">我的订单</text>
        <text class="menu-arrow">›</text>
      </view>
      <view class="menu-item" @click="goFavorites">
        <text class="menu-icon">❤️</text>
        <text class="menu-text">我的收藏</text>
        <text class="menu-arrow">›</text>
      </view>
      <view class="menu-item" @click="goAddress">
        <text class="menu-icon">📍</text>
        <text class="menu-text">收货地址</text>
        <text class="menu-arrow">›</text>
      </view>
      <view class="menu-item" @click="goAbout">
        <text class="menu-icon">ℹ️</text>
        <text class="menu-text">关于我们</text>
        <text class="menu-arrow">›</text>
      </view>
    </view>

    <!-- 退出 -->
    <view class="logout-btn" v-if="isLogin" @click="doLogout">退出登录</view>
  </view>
</template>

<script setup lang="ts">
import { ref } from 'vue'
import { onShow } from '@dcloudio/uni-app'
import { getMe } from '@/api'

const isLogin = ref(false)
const user = ref<any>({})

onShow(async () => {
  const token = uni.getStorageSync('token')
  isLogin.value = !!token
  if (token) {
    try {
      const raw = uni.getStorageSync('user')
      if (raw) user.value = JSON.parse(raw)
      const res = await getMe()
      if (res.success && res.data) {
        user.value = res.data.user || res.data
        uni.setStorageSync('user', JSON.stringify(user.value))
      }
    } catch (e) {}
  }
})

function goLogin() { uni.navigateTo({ url: '/pages/login/index' }) }
function goOrders() {
  if (!isLogin.value) { uni.navigateTo({ url: '/pages/login/index' }); return }
  uni.navigateTo({ url: '/pages/orders/index' })
}
function goFavorites() {
  uni.showToast({ title: '收藏功能开发中', icon: 'none' })
}
function goAddress() {
  uni.showToast({ title: '地址管理开发中', icon: 'none' })
}
function goAbout() {
  uni.showToast({ title: '爱艺术 - 俄罗斯手工玩偶', icon: 'none' })
}
function doLogout() {
  uni.showModal({
    title: '确认退出',
    content: '确定要退出登录吗？',
    success: (res) => {
      if (res.confirm) {
        uni.removeStorageSync('token')
        uni.removeStorageSync('user')
        isLogin.value = false
        user.value = {}
        uni.showToast({ title: '已退出', icon: 'success' })
      }
    }
  })
}
function uploadAvatar() {
  uni.chooseImage({
    count: 1,
    success: async (res) => {
      const filePath = res.tempFilePaths[0]
      const { uploadAvatar } = await import('@/api')
      const r: any = await uploadAvatar(filePath)
      if (r?.success) {
        user.value.avatar = r.data.url || r.data.avatar_url
        uni.setStorageSync('user', JSON.stringify(user.value))
        uni.showToast({ title: '头像已更新', icon: 'success' })
      }
    }
  })
}
</script>

<style>
.page { background: #f5f5f5; min-height: 100vh; }

.login-area { display: flex; flex-direction: column; align-items: center; padding: 80rpx 0; background: #fff; }
.avatar-placeholder { width: 120rpx; height: 120rpx; border-radius: 60rpx; background: #f0f0f0; }
.login-tip { font-size: 30rpx; color: #8B9E87; margin-top: 24rpx; }

.user-area { display: flex; align-items: center; padding: 40rpx 32rpx; background: #fff; }
.avatar { width: 120rpx; height: 120rpx; border-radius: 60rpx; background: #f0f0f0; }
.user-info { margin-left: 24rpx; }
.user-name { display: block; font-size: 34rpx; font-weight: bold; color: #333; }
.user-code { display: block; font-size: 24rpx; color: #999; margin-top: 4rpx; }

.menu-section { background: #fff; margin-top: 16rpx; }
.menu-item { display: flex; align-items: center; padding: 28rpx 32rpx; border-bottom: 1rpx solid #f5f5f5; }
.menu-item:last-child { border-bottom: none; }
.menu-icon { font-size: 36rpx; width: 56rpx; text-align: center; }
.menu-text { flex: 1; font-size: 30rpx; color: #333; }
.menu-arrow { font-size: 32rpx; color: #ccc; }

.logout-btn { text-align: center; margin: 40rpx 32rpx; padding: 24rpx; background: #fff; border-radius: 16rpx; font-size: 30rpx; color: #e74c3c; }
</style>
