const http = require("node:http");
const fs = require("node:fs");
const path = require("node:path");

const root = path.resolve("assets/UI/new-crab-icons");
const textureRoot = path.resolve("Crabmodels");
http.createServer((request, response) => {
  const textureMatch = /^\/textures\/([A-Za-z]+Crab_Color\.png)$/.exec(request.url);
  if (textureMatch) {
    fs.createReadStream(path.join(textureRoot, textureMatch[1]))
      .on("error", () => response.writeHead(404).end())
      .pipe(response.writeHead(200, { "Content-Type": "image/png" }));
    return;
  }
  const name = path.basename(decodeURIComponent(request.url.slice(1)));
  if (!/^[A-Za-z]+(?:Crab|Egg)\.png$/.test(name)) {
    response.writeHead(404).end();
    return;
  }
  const file = path.join(root, name);
  fs.createReadStream(file)
    .on("error", () => response.writeHead(404).end())
    .pipe(response.writeHead(200, { "Content-Type": "image/png" }));
}).listen(8765, "127.0.0.1", () => console.log("Serving new crab icons on 127.0.0.1:8765"));
