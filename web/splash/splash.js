function removeSplashFromWeb() {
  const elem = document.getElementById("splash");
  if (elem) {
    elem.remove();
  }
  document.body.style.background = "transparent";
}
