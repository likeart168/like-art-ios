<template>
  <view class="page">
    <!-- 搜索栏 -->
    <view class="search-bar">
      <input class="search-input" v-model="keyword" placeholder="搜索商品" @confirm="doSearch" />
      <text class="search-btn" @click="doSearch">搜索</text>
    </view>

    <!-- 分类筛选 -->
    <scroll-view scroll-x class="filter-row">
      <text class="filter-item" :class="{ active: !activeCat }" @click="activeCat = 0">全部</text>
      <text class="filter-item" v-for="c in categories" :key="c.id" :class="{ active: activeCat === c.id }" @click="activeCat = c.id">{{ c.name_zh || c.name }}</text>
    </scroll-view>

    <!-- 排序 -->
    <view class="sort-row">
      <text class="sort-item" :class="{ active: sortBy === 'newest' }" @click="sortBy = 'newest'">最新</text>
      <text class="sort-item" :class="{ active: sortBy === 'favorites' }" @click="sortBy = 'favorites'">最热</text>
      <text class="sort-item" :class="{ active: sortBy === 'price_asc' }" @click="sortBy = 'price_asc'">价格↑</text>
      <text class="sort-item" :class="{ active: sortBy === 'price_desc' }" @click="sortBy = 'price_desc'">价格↓</text>
    </view>

    <!-- 瀑布流 -->
    <view class="waterfall">
      <view class="wf-col">
        <view class="card" v-for="p in leftList" :key="'l'+p.id" @click="goDetail(p.id)">
          <image :src="p.image" mode="aspectFill" class="card-img" :style="{ height: p.imgH + 'rpx' }" />
          <text class="card-title">{{ p.title }}</text>
          <view class="card-bottom">
            <text class="card-price">¥{{ p.price }}</text>
            <text class="card-fav">❤️{{ p.favorites }}</text>
          </view>
        </view>
      </view>
      <view class="wf-col">
        <view class="card" v-for="p in rightList" :key="'r'+p.id" @click="goDetail(p.id)">
          <image :src="p.image" mode="aspectFill" class="card-img" :style="{ height: p.imgH + 'rpx' }" />
          <text class="card-title">{{ p.title }}</text>
          <view class="card-bottom">
            <text class="card-price">¥{{ p.price }}</text>
            <text class="card-fav">❤️{{ p.favorites }}</text>
          </view>
        </view>
      </view>
    </view>

    <!-- 加载更多 -->
    <view class="load-more" v-if="hasMore" @click="loadMore">
      <text>加载更多</text>
    </view>
    <view class="load-more" v-else-if="products.length > 0">
      <text class="no-more">— 到底了 —</text>
    </view>
  </view>
</template>

<script setup lang="ts">
import { ref, watch } from 'vue'
import { onLoad } from '@dcloudio/uni-app'
import { getProducts, getCategories } from '@/api'

const keyword = ref('')
const activeCat = ref(0)
const sortBy = ref('newest')
const categories = ref<any[]>([])
const products = ref<any[]>([])
const leftList = ref<any[]>([])
const rightList = ref<any[]>([])
const page = ref(1)
const hasMore = ref(true)

onLoad(async (options: any) => {
  if (options?.category) activeCat.value = parseInt(options.category) || 0
  const catRes = await getCategories()
  if (catRes.success) categories.value = (catRes.data || []).map((c: any) => ({
    id: c.id, name_zh: c.name_zh || c.name || ''
  }))
  fetchProducts()
})

watch([activeCat, sortBy], () => { page.value = 1; products.value = []; fetchProducts() })

function mapProduct(p: any) {
  const images = typeof p.images === 'string' ? JSON.parse(p.images || '[]') : (p.images || [])
  const h = 280 + Math.floor(Math.random() * 160) // 随机高度模拟瀑布流
  return {
    id: p.id, title: p.title_zh || p.title || '',
    price: p.price_cny || p.price || 0, image: images[0] || '',
    favorites: p.favorites || p.favorite_count || 0, imgH: h
  }
}

function splitColumns(list: any[]) {
  const l: any[] = [], r: any[] = []
  list.forEach((item, i) => { if (i % 2 === 0) l.push(item); else r.push(item) })
  leftList.value = l; rightList.value = r
}

async function fetchProducts() {
  uni.showLoading({ title: '加载中' })
  try {
    const params: any = { page: page.value, limit: 20, sort: sortBy.value }
    if (activeCat.value) params.category = activeCat.value
    if (keyword.value) params.search = keyword.value
    const res = await getProducts(params)
    if (res.success) {
      const list = (res.data.products || res.data || []).map(mapProduct)
      if (page.value === 1) products.value = list
      else products.value = [...products.value, ...list]
      splitColumns(products.value)
      hasMore.value = list.length >= 20
    }
  } catch (e) { console.error(e) }
  uni.hideLoading()
}

function doSearch() { page.value = 1; products.value = []; fetchProducts() }
function loadMore() { page.value++; fetchProducts() }
function goDetail(id: number) { uni.navigateTo({ url: `/pages/product/index?id=${id}` }) }
</script>

<style>
.page { background: #f5f5f5; min-height: 100vh; }
.search-bar { display: flex; padding: 16rpx 24rpx; background: #fff; gap: 12rpx; }
.search-input { flex: 1; height: 68rpx; background: #f5f5f5; border-radius: 34rpx; padding: 0 24rpx; font-size: 28rpx; }
.search-btn { padding: 0 24rpx; line-height: 68rpx; font-size: 28rpx; color: #8B9E87; }

.filter-row { white-space: nowrap; background: #fff; padding: 16rpx 24rpx; border-top: 1rpx solid #f0f0f0; }
.filter-item { display: inline-block; padding: 12rpx 28rpx; margin-right: 16rpx; border-radius: 24rpx; font-size: 26rpx; color: #666; background: #f5f5f5; }
.filter-item.active { background: #8B9E87; color: #fff; }

.sort-row { display: flex; padding: 16rpx 24rpx; gap: 32rpx; background: #fff; margin-bottom: 8rpx; }
.sort-item { font-size: 26rpx; color: #999; }
.sort-item.active { color: #8B9E87; font-weight: bold; }

.waterfall { display: flex; gap: 12rpx; padding: 12rpx 16rpx; }
.wf-col { flex: 1; display: flex; flex-direction: column; gap: 12rpx; }
.card { background: #fff; border-radius: 12rpx; overflow: hidden; }
.card-img { width: 100%; background: #f0f0f0; }
.card-title { display: block; padding: 12rpx 16rpx 4rpx; font-size: 26rpx; color: #333; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.card-bottom { display: flex; justify-content: space-between; padding: 0 16rpx 16rpx; }
.card-price { font-size: 30rpx; font-weight: bold; color: #e74c3c; }
.card-fav { font-size: 22rpx; color: #ccc; }

.load-more { text-align: center; padding: 32rpx; color: #8B9E87; font-size: 28rpx; }
.no-more { color: #ccc; }
</style>
