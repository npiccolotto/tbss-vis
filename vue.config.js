module.exports = {
  publicPath:
    process.env.NODE_ENV === "local"
      ? "/"
      : `/${process.env.VUE_APP_PUBLIC_PATH}`
};
