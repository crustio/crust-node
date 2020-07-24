
const Joi = require('joi')

const karstSchema = Joi.object({
  base_path: Joi.string().required(),
  tracker_addrs: Joi.array().items(Joi.string()),
  port: Joi.number().port().default(17000),
})

module.exports = {
  karstSchema,
}
