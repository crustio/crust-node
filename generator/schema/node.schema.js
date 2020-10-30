const Joi = require('joi')

const nodeSchema = Joi.object({
  chain: Joi.string().valid('authority', 'full').required(),
  sworker: Joi.string().valid('enable', 'disable').required(),
})

module.exports = {
  nodeSchema,
}