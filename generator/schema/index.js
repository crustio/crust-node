
const Joi = require('joi')
const { apiSchema } = require('./api.schema')
const { chainSchema } = require('./chain.schema')
const { karstSchema } = require('./karst.schema')
const { identitySchema } = require('./identity.schema')
const { teeSchema } = require('./tee.schema')

const configSchema = Joi.object({
  identity: identitySchema.required(),
  chain: chainSchema.required(),
  api: apiSchema.required(),
  tee: teeSchema.required(),
  karst: karstSchema.required(),
})

module.exports = {
  configSchema,
}
