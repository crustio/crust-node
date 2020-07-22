const Joi = require('joi')
const bluebird = require('bluebird')

const backupSchema = Joi.object({
  address: Joi.string().required().external(async (v) => {
    console.log('validing address', v)
  }),
  encoded: Joi.string().required(),
  encoding: Joi.object({
    content: Joi.array().items(Joi.string()).min(1).required(),
    type: Joi.string().required(),
    version: Joi.string().required(),
  }).required(),
  meta: Joi.object({
    genesisHash: Joi.string().length(66).regex(/^0x[0-9a-f]+$/).required(),
    name: Joi.string().required(),
    tags: Joi.array().items(Joi.string()),
    whenCreated: Joi.date().timestamp().raw(),
  }),
})

const identitySchema = Joi.object({
  backup: backupSchema.required(),
  password: Joi.string().min(1).required(),
})

module.exports = {
  identitySchema,
}
