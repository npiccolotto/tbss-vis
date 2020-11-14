<template>
  <div><ParameterInput /></div>
</template>
<script lang="ts">
import ParameterInput from "@/components/parameter-input/ParameterInput.vue";
import { Component, Prop, Vue } from "vue-property-decorator";

@Component({
  components: { ParameterInput }
})
export default class ParameterInputView extends Vue {}
</script>

<style scoped lang="less"></style>
