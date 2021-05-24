const Joi = require('joi')

const apiSchema = Joi.object({
  url: Joi.string().required().default("ws://127.0.0.1:19944"),
})

module.exports = {
  apiSchema,
}
