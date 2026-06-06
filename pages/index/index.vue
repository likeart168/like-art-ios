<template>
  <view class="container">
    <web-view 
      :src="url" 
      @message="onMessage"
      @onPostMessage="onMessage"
    ></web-view>
  </view>
</template>

<script setup lang="ts">
import { ref } from 'vue';

const url = ref('https://like-art.com');

const onMessage = (e: any) => {
  console.log('WebView message:', e.detail);
};
</script>

<style>
.container {
  width: 100vw;
  height: 100vh;
}
</style>
