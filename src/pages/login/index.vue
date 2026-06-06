<template>
  <view class="page">
    <view class="logo-area">
      <image class="logo" src="/static/logo.png" mode="aspectFit" />
      <text class="brand">爱艺术 Like-Art</text>
    </view>

    <!-- 登录表单 -->
    <view class="form" v-if="mode === 'login'">
      <view class="field">
        <text class="label">手机号</text>
        <input class="input" v-model="phone" type="number" maxlength="11" placeholder="请输入手机号" />
      </view>
      <view class="field">
        <text class="label">密码</text>
        <input class="input" v-model="password" type="password" placeholder="请输入密码" />
      </view>
      <view class="btn" @click="doLogin">登录</view>
      <text class="switch" @click="mode = 'register'">还没有账号？立即注册</text>
    </view>

    <!-- 注册表单 -->
    <view class="form" v-if="mode === 'register'">
      <view class="field">
        <text class="label">手机号</text>
        <input class="input" v-model="phone" type="number" maxlength="11" placeholder="请输入手机号" />
      </view>
      <view class="field">
        <text class="label">设置密码</text>
        <input class="input" v-model="password" type="password" placeholder="6-20位密码" />
      </view>
      <view class="field">
        <text class="label">昵称（选填）</text>
        <input class="input" v-model="name" placeholder="给自己起个名字" />
      </view>
      <view class="btn" @click="doRegister">注册</view>
      <text class="switch" @click="mode = 'login'">已有账号？去登录</text>
    </view>
  </view>
</template>

<script setup lang="ts">
import { ref } from 'vue'
import { login, register } from '@/api'

const mode = ref<'login' | 'register'>('login')
const phone = ref('')
const password = ref('')
const name = ref('')

async function doLogin() {
  if (!phone.value || !password.value) {
    uni.showToast({ title: '请填写手机号和密码', icon: 'none' })
    return
  }
  uni.showLoading({ title: '登录中' })
  const res = await login(phone.value, password.value)
  uni.hideLoading()
  if (res.success) {
    uni.setStorageSync('token', res.data.token || '')
    uni.setStorageSync('user', JSON.stringify(res.data.user || {}))
    uni.showToast({ title: '登录成功' })
    setTimeout(() => uni.switchTab({ url: '/pages/index/index' }), 800)
  } else {
    uni.showToast({ title: res.message || '登录失败', icon: 'none' })
  }
}

async function doRegister() {
  if (!phone.value || !password.value) {
    uni.showToast({ title: '请填写手机号和密码', icon: 'none' })
    return
  }
  if (password.value.length < 6) {
    uni.showToast({ title: '密码至少6位', icon: 'none' })
    return
  }
  uni.showLoading({ title: '注册中' })
  const res = await register(phone.value, password.value, name.value || undefined)
  uni.hideLoading()
  if (res.success) {
    uni.setStorageSync('token', res.data.token || '')
    uni.setStorageSync('user', JSON.stringify(res.data.user || {}))
    uni.showToast({ title: '注册成功' })
    setTimeout(() => uni.switchTab({ url: '/pages/index/index' }), 800)
  } else {
    uni.showToast({ title: res.message || '注册失败', icon: 'none' })
  }
}
</script>

<style>
.page { min-height: 100vh; background: #fff; display: flex; flex-direction: column; align-items: center; padding-top: 120rpx; }
.logo-area { text-align: center; margin-bottom: 60rpx; }
.logo { width: 140rpx; height: 140rpx; }
.brand { display: block; font-size: 36rpx; font-weight: bold; color: #333; margin-top: 20rpx; }

.form { width: 600rpx; }
.field { margin-bottom: 32rpx; }
.label { display: block; font-size: 28rpx; color: #666; margin-bottom: 12rpx; }
.input { width: 100%; height: 88rpx; border: 2rpx solid #e0e0e0; border-radius: 12rpx; padding: 0 24rpx; font-size: 30rpx; box-sizing: border-box; }
.btn { width: 100%; height: 88rpx; line-height: 88rpx; text-align: center; background: #8B9E87; color: #fff; font-size: 32rpx; border-radius: 12rpx; margin-top: 16rpx; }
.switch { display: block; text-align: center; color: #8B9E87; font-size: 28rpx; margin-top: 24rpx; }
</style>
