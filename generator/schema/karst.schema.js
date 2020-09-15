
const Joi = require('joi')

const karstSchema = Joi.object({
  tracker_addrs: Joi.string().required(),
})

module.exports = {
  karstSchema,
}
