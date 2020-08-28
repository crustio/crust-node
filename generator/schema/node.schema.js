const Joi = require('joi')

const nodeSchema = Joi.object({
  chain: Joi.string().valid('authority', 'full', 'light').required(),
  sworker: Joi.string().valid('enable', 'disable').required(),
  karst: Joi.string().valid('enable', 'disable').required(),
})

module.exports = {
  nodeSchema,
}