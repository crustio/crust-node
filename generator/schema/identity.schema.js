const Joi = require('joi')
const bluebird = require('bluebird')
const { logger } = require('../logger')

const backupSchema = Joi.object({
  address: Joi.string().required(),
})

const identitySchema = Joi.object({
  backup: Joi.string().custom((value, helpers) => {
    try {
      const result = backupSchema.validate(JSON.parse(value), {allowUnknown: true})
      if (result.error) {
        return helpers.error(result.error)
      }
      return result.value
    } catch(ex) {
      logger.error('Failed to parse json: %s', ex)
      return helpers.error('Backup is not a valid json string')
    }
  }).required(),
  password: Joi.string().min(1).required(),
})

module.exports = {
  identitySchema,
}
