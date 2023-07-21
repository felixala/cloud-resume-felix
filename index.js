const counter = document.querySelector(".counter-number");
async function updateCounter() {
    let response = await fetch("https://bu62nrllqqhkmfy3l4siid6mf40nkgbm.lambda-url.us-east-1.on.aws/");
    let data = await response.json();
    counter.innerHTML = ` This page has ${data} Views!`;
}

updateCounter();