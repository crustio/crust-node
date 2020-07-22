const Joi = require('joi')

const apiSchema = Joi.object({
  port: Joi.number().port().default(5666),
})

module.exports = {
  apiSchema,
}
