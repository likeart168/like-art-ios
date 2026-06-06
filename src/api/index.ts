// API 工具模块 — 爱艺术 UniApp
const BASE = 'https://like-art.com'

// 通用请求
async function request<T = any>(url: string, options: any = {}): Promise<{ success: boolean; data: T; message?: string }> {
  const token = uni.getStorageSync('token') || ''
  const header: any = { 'Content-Type': 'application/json' }
  if (token) header['Authorization'] = `Bearer ${token}`

  try {
    const res = await uni.request({
      url: BASE + url,
      method: options.method || 'GET',
      data: options.data,
      header,
      timeout: 15000
    })
    return res.data as any
  } catch (e: any) {
    return { success: false, data: null as any, message: e.errMsg || '网络错误' }
  }
}

// ====== 商品 ======
export function getProducts(params?: any) {
  const qs = params ? '?' + Object.entries(params).map(([k, v]) => `${k}=${v}`).join('&') : ''
  return request(`/api/products${qs}`)
}
export function getProduct(id: number) {
  return request(`/api/products/${id}`)
}
export function toggleFavorite(productId: number) {
  return request(`/api/products/${productId}/favorite`, { method: 'POST' })
}
export function getFavorites() {
  return request('/api/products/favorites')
}
export function getCategories() {
  return request('/api/categories')
}

// ====== 认证 ======
export function login(phone: string, password: string) {
  return request('/api/auth/login', { method: 'POST', data: { phone, password } })
}
export function register(phone: string, password: string, name?: string) {
  return request('/api/auth/register', { method: 'POST', data: { phone, password, name } })
}
export function getMe() {
  return request('/api/auth/me')
}
export function uploadAvatar(filePath: string) {
  return new Promise((resolve, reject) => {
    const token = uni.getStorageSync('token') || ''
    uni.uploadFile({
      url: BASE + '/api/auth/upload-avatar',
      filePath,
      name: 'avatar',
      header: { 'Authorization': `Bearer ${token}` },
      success: (res) => resolve(JSON.parse(res.data)),
      fail: reject
    })
  })
}

// ====== 订单 ======
export function getOrders(params?: any) {
  const qs = params ? '?' + new URLSearchParams(params).toString() : ''
  return request(`/api/orders${qs}`)
}
export function getOrder(id: number) {
  return request(`/api/orders/${id}`)
}
export function createOrder(data: any) {
  return request('/api/orders', { method: 'POST', data })
}

// ====== 地址 ======
export function getAddresses() {
  return request('/api/user/addresses')
}
export function saveAddress(data: any) {
  return request('/api/user/addresses', { method: 'POST', data })
}
export function deleteAddress(id: number) {
  return request(`/api/user/addresses/${id}`, { method: 'DELETE' })
}

// ====== 议价 ======
export function makeOffer(productId: number, price: number, message?: string) {
  return request('/api/bargain/offer', { method: 'POST', data: { product_id: productId, price, message } })
}

// ====== 拍卖 ======
export function getAuctions(params?: any) {
  const qs = params ? '?' + new URLSearchParams(params).toString() : ''
  return request(`/api/auctions${qs}`)
}
export function placeBid(auctionId: number, amount: number) {
  return request(`/api/auctions/${auctionId}/bid`, { method: 'POST', data: { amount } })
}

// ====== 服务费 ======
export function getServiceFee() {
  return request('/api/service-fee')
}

// ====== 购物车 (localStorage) ======
const CART_KEY = 'like_art_cart'
export function getCart(): CartItem[] {
  try {
    return JSON.parse(uni.getStorageSync(CART_KEY) || '[]')
  } catch { return [] }
}
export function saveCart(items: CartItem[]) {
  uni.setStorageSync(CART_KEY, JSON.stringify(items))
}
export function addToCart(product: CartItem) {
  const cart = getCart()
  const idx = cart.findIndex(i => i.id === product.id)
  if (idx >= 0) {
    cart[idx].qty = (cart[idx].qty || 1) + 1
  } else {
    cart.push({ ...product, qty: 1 })
  }
  saveCart(cart)
  return cart
}
export function removeFromCart(productId: number) {
  const cart = getCart().filter(i => i.id !== productId)
  saveCart(cart)
  return cart
}

export interface CartItem {
  id: number
  title: string
  price: number
  image: string
  qty: number
}
