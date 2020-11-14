<template>
  <div class="folder">
    <div>
      <div v-on:click="toggle" class="folder__title">
        {{ title }}
        <font-awesome-icon
          v-if="visible"
          size="xs"
          fixed-width
          v-bind:icon="['far', 'eye-slash']"
        ></font-awesome-icon>
        <font-awesome-icon
          v-else
          size="xs"
          fixed-width
          v-bind:icon="['far', 'eye']"
        ></font-awesome-icon>
      </div>
    </div>
    <div v-show="visible">
      <slot></slot>
    </div>
  </div>
</template>

<script lang="ts">
import { Vue, Prop, Component } from "vue-property-decorator";

@Component
export default class Folder extends Vue {
  @Prop({ default: "title" }) public title!: string;

  public visible = true;

  toggle() {
    this.visible = !this.visible;
  }
}
</script>
<style lang="less" scoped>
.folder {
  display: grid;
  grid-template-columns: 25px max-content;

  &__title {
    // font-weight: 700;
    white-space: nowrap;
    position: absolute;
    color: gray;
    transform-origin: 0 0;
    transform: rotate(-90deg) translate(-100%, 0%);
    user-select: none;
    cursor: pointer;
  }
}
</style>
