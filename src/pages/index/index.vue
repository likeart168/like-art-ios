<template>
  <view class="page">
    <!-- Banner 轮播 -->
    <swiper class="banner" indicator-dots autoplay circular>
      <swiper-item v-for="b in banners" :key="b.id">
        <image :src="b.image" mode="aspectFill" class="banner-img" @click="goDetail(b.product_id)" />
      </swiper-item>
    </swiper>

    <!-- 分类快捷入口 -->
    <scroll-view scroll-x class="cats">
      <view class="cat-item" v-for="c in categories" :key="c.id" @click="goCategory(c.id)">
        <image :src="c.icon" mode="aspectFit" class="cat-icon" />
        <text class="cat-name">{{ c.name_zh || c.name }}</text>
      </view>
    </scroll-view>

    <!-- 新品上市 -->
    <view class="section">
      <view class="section-hd"><text class="section-title">新品上市</text><text class="section-more" @click="goAll">全部 ›</text></view>
      <scroll-view scroll-x class="product-row">
        <view class="product-card" v-for="p in newProducts" :key="p.id" @click="goDetail(p.id)">
          <image :src="p.image" mode="aspectFill" class="p-img" />
          <text class="p-title">{{ p.title }}</text>
          <text class="p-price">¥{{ p.price }}</text>
        </view>
        <view class="product-card empty-card" v-if="!newProducts.length">
          <text class="empty-text">暂无新品</text>
        </view>
      </scroll-view>
    </view>

    <!-- 精选作品 (收藏+点击排序) -->
    <view class="section">
      <view class="section-hd"><text class="section-title">精选作品</text></view>
      <view class="grid">
        <view class="card" v-for="p in featuredProducts" :key="'f'+p.id" @click="goDetail(p.id)">
          <image :src="p.image" mode="aspectFill" class="card-img" />
          <view class="card-info">
            <text class="card-title">{{ p.title }}</text>
            <view class="card-bottom">
              <text class="card-price">¥{{ p.price }}</text>
              <view class="card-stats">
                <text class="stat">❤️ {{ p.favorites || 0 }}</text>
              </view>
            </view>
          </view>
        </view>
        <view class="card empty-card" v-if="!featuredProducts.length">
          <text class="empty-text">暂无精选</text>
        </view>
      </view>
    </view>
  </view>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { getProducts, getCategories } from '@/api'

const banners = ref<any[]>([])
const categories = ref<any[]>([])
const newProducts = ref<any[]>([])
const featuredProducts = ref<any[]>([])

function mapProduct(p: any) {
  const images = typeof p.images === 'string' ? JSON.parse(p.images || '[]') : (p.images || [])
  return {
    id: p.id,
    title: p.title_zh || p.title || '',
    price: p.price_cny || p.price || 0,
    image: images[0] || '',
    favorites: p.favorites || p.favorite_count || 0,
    views: p.views || p.view_count || 0,
    category_id: p.category_id
  }
}

onMounted(async () => {
  try {
    // 分类
    const catRes = await getCategories()
    if (catRes.success) {
      categories.value = (catRes.data || []).slice(0, 8).map((c: any) => ({
        ...c,
        name_zh: c.name_zh || c.name || ''
      }))
    }
    // Banner — 用精选商品做轮播
    const res = await getProducts({ sort: 'favorites', limit: 5 })
    if (res.success) {
      const list = (res.data.products || res.data || []).map(mapProduct)
      banners.value = list.map((p: any) => ({ id: p.id, image: p.image, product_id: p.id }))
      featuredProducts.value = list
    }
    // 新品
    const newRes = await getProducts({ sort: 'newest', limit: 10 })
    if (newRes.success) {
      newProducts.value = (newRes.data.products || newRes.data || []).map(mapProduct)
    }
  } catch (e) {
    console.error(e)
  }
})

function goDetail(id: number) {
  uni.navigateTo({ url: `/pages/product/index?id=${id}` })
}
function goCategory(id: number) {
  uni.navigateTo({ url: `/pages/products/index?category=${id}` })
}
function goAll() {
  uni.switchTab({ url: '/pages/products/index' })
}
</script>

<style>
.page { background: #f5f5f5; min-height: 100vh; padding-bottom: 40rpx; }
.banner { width: 100%; height: 360rpx; }
.banner-img { width: 100%; height: 100%; }
.cats { white-space: nowrap; padding: 24rpx; background: #fff; margin-bottom: 16rpx; }
.cat-item { display: inline-flex; flex-direction: column; align-items: center; width: 120rpx; margin-right: 16rpx; }
.cat-icon { width: 72rpx; height: 72rpx; border-radius: 16rpx; background: #f0f0f0; }
.cat-name { font-size: 22rpx; color: #666; margin-top: 8rpx; }

.section { margin: 0 24rpx 24rpx; }
.section-hd { display: flex; justify-content: space-between; align-items: center; padding: 16rpx 0; }
.section-title { font-size: 34rpx; font-weight: bold; color: #333; }
.section-more { font-size: 26rpx; color: #999; }

.product-row { white-space: nowrap; }
.product-card { display: inline-block; width: 280rpx; margin-right: 16rpx; background: #fff; border-radius: 16rpx; overflow: hidden; }
.product-card:last-child { margin-right: 0; }
.p-img { width: 280rpx; height: 280rpx; }
.p-title { display: block; padding: 12rpx 16rpx 4rpx; font-size: 26rpx; color: #333; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.p-price { display: block; padding: 0 16rpx 16rpx; font-size: 30rpx; font-weight: bold; color: #e74c3c; }

.grid { display: flex; flex-wrap: wrap; gap: 16rpx; }
.card { width: calc(50% - 8rpx); background: #fff; border-radius: 16rpx; overflow: hidden; }
.card-img { width: 100%; height: 340rpx; }
.card-info { padding: 16rpx; }
.card-title { font-size: 26rpx; color: #333; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; display: block; }
.card-bottom { display: flex; justify-content: space-between; align-items: center; margin-top: 8rpx; }
.card-price { font-size: 30rpx; font-weight: bold; color: #e74c3c; }
.card-stats { display: flex; gap: 8rpx; }
.stat { font-size: 22rpx; color: #999; }
.empty-card { display: flex; align-items: center; justify-content: center; height: 200rpx; }
.empty-text { color: #ccc; font-size: 28rpx; }
</style>
