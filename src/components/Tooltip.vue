<template>
  <font-awesome-icon
    v-tooltip="text"
    v-bind:size="size"
    fixed-width
    v-bind:icon="['far', 'question-circle']"
  ></font-awesome-icon>
</template>

<script lang="ts">
import { Vue, Prop, Component } from "vue-property-decorator";
@Component
export default class Tooltip extends Vue {
  @Prop({ default: "" }) public text!: string;
  @Prop({ default: "xs" }) public size!: string;
}
</script>
