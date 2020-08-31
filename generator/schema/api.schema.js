const Joi = require('joi')

const apiSchema = Joi.object({
  port: Joi.number().port().default(56666),
})

module.exports = {
  apiSchema,
}
