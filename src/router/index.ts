import Vue from "vue";
import VueRouter from "vue-router";
import DataLoad from "../views/DataLoad.vue";
import ParameterInput from "../views/ParameterInput.vue";
import Main from "../views/Main.vue";

Vue.use(VueRouter);

const routes = [
  {
    path: "/data-load",
    name: "dataload",
    component: DataLoad
  },
  {
    path: "/parameter-input",
    name: "parameterinput",
    component: ParameterInput
  },
  { path: "/", name: "main", component: Main }
];

const router = new VueRouter({
  routes
});

export default router;
