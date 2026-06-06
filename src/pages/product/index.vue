<template>
  <view class="page" v-if="product.id">
    <!-- 图片轮播 -->
    <swiper class="img-swiper" indicator-dots circular :autoplay="false">
      <swiper-item v-for="(img, i) in images" :key="i">
        <image :src="img" mode="aspectFill" class="swiper-img" @click="previewImages(i)" />
      </swiper-item>
    </swiper>

    <!-- 商品信息 -->
    <view class="info">
      <view class="info-hd">
        <text class="p-name">{{ product.title }}</text>
        <view class="fav-btn" @click="doFavorite">
          <text :class="product.is_favorite ? 'fav-active' : 'fav'">{{ product.is_favorite ? '❤️' : '🤍' }}</text>
          <text class="fav-count">{{ product.favorites || 0 }}</text>
        </view>
      </view>
      <text class="p-price">¥{{ product.price }}</text>
      <text class="p-artist" v-if="product.artist">艺术家：{{ product.artist }}</text>
      <text class="p-desc" v-if="product.description">{{ product.description }}</text>
    </view>

    <!-- 操作按钮 -->
    <view class="actions">
      <view class="btn-add-cart" @click="doAddCart">加入购物车</view>
      <view class="btn-buy" @click="doBuyNow">立即购买</view>
    </view>

    <!-- 议价入口 -->
    <view class="bargain-section">
      <view class="section-title">喜欢就出价</view>
      <view class="bargain-row">
        <input class="bargain-input" v-model="bargainPrice" type="digit" placeholder="输入你的心理价位" />
        <view class="btn-bargain" @click="doBargain">出价</view>
      </view>
    </view>
  </view>

  <!-- 加载中 -->
  <view class="loading" v-else>
    <text>加载中...</text>
  </view>
</template>

<script setup lang="ts">
import { ref } from 'vue'
import { onLoad } from '@dcloudio/uni-app'
import { getProduct, toggleFavorite, addToCart as addCart, makeOffer } from '@/api'

const product = ref<any>({})
const images = ref<string[]>([])
const bargainPrice = ref('')

onLoad((options: any) => {
  const id = parseInt(options?.id) || 0
  if (id) fetchProduct(id)
})

async function fetchProduct(id: number) {
  uni.showLoading({ title: '加载中' })
  try {
    const res = await getProduct(id)
    if (res.success) {
      const p = res.data.product || res.data
      product.value = {
        id: p.id,
        title: p.title_zh || p.title || '',
        price: p.price_cny || p.price || 0,
        description: p.description_zh || p.description || '',
        artist: p.artist_name || '',
        favorites: p.favorites || p.favorite_count || 0,
        is_favorite: p.is_favorite || false,
        category_id: p.category_id
      }
      const imgs = typeof p.images === 'string' ? JSON.parse(p.images || '[]') : (p.images || [])
      images.value = imgs.length ? imgs : ['/static/logo.png']
    }
  } catch (e) {
    uni.showToast({ title: '加载失败', icon: 'none' })
  }
  uni.hideLoading()
}

function previewImages(idx: number) {
  uni.previewImage({ current: idx, urls: images.value })
}

async function doFavorite() {
  const res = await toggleFavorite(product.value.id)
  if (res.success) {
    product.value.is_favorite = !product.value.is_favorite
    product.value.favorites += product.value.is_favorite ? 1 : -1
    uni.showToast({ title: product.value.is_favorite ? '已收藏' : '已取消', icon: 'none' })
  }
}

function doAddCart() {
  addCart({
    id: product.value.id,
    title: product.value.title,
    price: product.value.price,
    image: images.value[0] || '',
    qty: 1
  })
  uni.showToast({ title: '已加入购物车', icon: 'success' })
}

function doBuyNow() {
  addCart({
    id: product.value.id,
    title: product.value.title,
    price: product.value.price,
    image: images.value[0] || '',
    qty: 1
  })
  uni.navigateTo({ url: '/pages/checkout/index' })
}

async function doBargain() {
  const price = parseFloat(bargainPrice.value)
  if (!price || price <= 0) {
    uni.showToast({ title: '请输入有效价格', icon: 'none' })
    return
  }
  uni.showLoading({ title: '提交中' })
  const res = await makeOffer(product.value.id, price)
  uni.hideLoading()
  if (res.success) {
    uni.showToast({ title: '出价成功，等待艺术家回复', icon: 'success' })
    bargainPrice.value = ''
  } else {
    uni.showToast({ title: res.message || '出价失败', icon: 'none' })
  }
}
</script>

<style>
.page { background: #f5f5f5; min-height: 100vh; padding-bottom: 40rpx; }

.img-swiper { width: 100%; height: 640rpx; }
.swiper-img { width: 100%; height: 100%; }

.info { background: #fff; margin: 16rpx 24rpx; border-radius: 16rpx; padding: 24rpx; }
.info-hd { display: flex; justify-content: space-between; align-items: flex-start; }
.p-name { font-size: 34rpx; font-weight: bold; color: #333; flex: 1; }
.fav-btn { display: flex; flex-direction: column; align-items: center; margin-left: 16rpx; }
.fav { font-size: 40rpx; }
.fav-active { font-size: 40rpx; }
.fav-count { font-size: 22rpx; color: #999; margin-top: 4rpx; }
.p-price { display: block; font-size: 44rpx; font-weight: bold; color: #e74c3c; margin-top: 16rpx; }
.p-artist { display: block; font-size: 26rpx; color: #666; margin-top: 8rpx; }
.p-desc { display: block; font-size: 28rpx; color: #999; margin-top: 16rpx; line-height: 1.6; }

.actions { display: flex; gap: 16rpx; padding: 0 24rpx; margin-bottom: 24rpx; }
.btn-add-cart { flex: 1; text-align: center; padding: 24rpx; background: #fff; border: 2rpx solid #8B9E87; border-radius: 12rpx; font-size: 30rpx; color: #8B9E87; }
.btn-buy { flex: 1; text-align: center; padding: 24rpx; background: #8B9E87; border-radius: 12rpx; font-size: 30rpx; color: #fff; }

.bargain-section { margin: 0 24rpx; background: #fff; border-radius: 16rpx; padding: 24rpx; }
.section-title { font-size: 30rpx; font-weight: bold; color: #333; margin-bottom: 16rpx; }
.bargain-row { display: flex; gap: 16rpx; align-items: center; }
.bargain-input { flex: 1; border: 2rpx solid #e0e0e0; border-radius: 12rpx; padding: 16rpx 20rpx; font-size: 28rpx; }
.btn-bargain { padding: 16rpx 32rpx; background: #e74c3c; color: #fff; border-radius: 12rpx; font-size: 28rpx; white-space: nowrap; }

.loading { display: flex; justify-content: center; align-items: center; height: 100vh; color: #999; }
</style>
