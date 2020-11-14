<template>
  <div v-if="isOpened" class="modal-mask">
    <div class="modal-wrapper">
      <div class="modal-container">
        <slot></slot>
      </div>
    </div>
  </div>
</template>

<script lang="ts">
import { Vue, Component, Prop } from "vue-property-decorator";

@Component({
  watch: {
    isOpened: function(n, o) {
      if (n === o) {
        return;
      }
      if (n) {
        document.body.style.position = "fixed";
      } else {
        document.body.style.position = "unset";
      }
    }
  }
})
export default class Modal extends Vue {
  @Prop({ type: Boolean, default: false }) private isOpened!: boolean;
}
</script>

<style lang="less" scoped>
.modal-mask {
  position: fixed;
  z-index: 9998;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
  background-color: rgba(0, 0, 0, 0.5);
  display: table;
  transition: opacity 0.3s ease;
}

.modal-wrapper {
  position: absolute;
  width: 95vw;
  height: 95vh;
  overflow: scroll;
  margin: 0px auto;
  padding: 20px 30px;
}

.modal-container {
  width: 100%;
  height: 100%;
  padding: 10px;
  background-color: #fff;
  border-radius: 2px;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.33);
  transition: all 0.3s ease;
  font-family: Helvetica, Arial, sans-serif;
}
</style>
