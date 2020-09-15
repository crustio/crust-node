
const Joi = require('joi')
const { apiSchema } = require('./api.schema')
const { chainSchema } = require('./chain.schema')
const { karstSchema } = require('./karst.schema')
const { identitySchema } = require('./identity.schema')
const { sworkerSchema } = require('./sworker.schema')
const { nodeSchema } = require('./node.schema')

function getConfigSchema(config) {
  sMap = {
    node: nodeSchema.required(),
    chain: chainSchema.required(),
  }

  if (config.node.sworker != "enable") {
    return Joi.object(sMap)
  }
  sMap["identity"] = identitySchema.required()
  sMap["sworker"] = sworkerSchema.required()

  if (config.node.karst != "enable") {
    return Joi.object(sMap)
  }
  sMap["karst"] = karstSchema.required()

  return Joi.object(sMap)
}

module.exports = {
  getConfigSchema,
}
