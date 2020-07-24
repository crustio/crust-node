const Joi = require('joi')
const bluebird = require('bluebird')
const { logger } = require('../logger')

const backupSchema = Joi.object({
  address: Joi.string().required(),
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
  backup: Joi.string().custom((value, helpers) => {
    try {
      logger.info('value: %s', value)
      const result = backupSchema.validate(JSON.parse(value))
      if (result.error) {
        return helpers.error(result.error)
      }
      return result.value
    } catch(ex) {
      logger.error('failed to parse json: %s', ex)
      return helpers.error('backup is not a valid json string')
    }
  }).required(),
  password: Joi.string().min(1).required(),
})

module.exports = {
  identitySchema,
}
