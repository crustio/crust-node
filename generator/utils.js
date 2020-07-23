const fs = require('fs-extra')
const shell = require('shelljs')
const yaml = require('js-yaml')

async function createDir(dir) {
  if(shell.mkdir('-p', dir).code !== 0) {
    throw `failed to create directory: ${dir}`
  }
}

async function writeConfig(path, cfg) {
  await fs.outputJson(path, cfg, {
    spaces: 2,
  })
  return true
}

async function writeYaml(path, cfg) {
  await fs.outputFile(path, yaml.safeDump(cfg, {
    ident: 2,
  }))
  return true
}


module.exports = {
  createDir,
  writeConfig,
  writeYaml,
}
