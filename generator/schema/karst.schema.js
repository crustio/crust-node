
const Joi = require('joi')

const karstSchema = Joi.object({
  tracker_addrs: Joi.string().required(),
  outer_tracker_addrs: Joi.string().default(),
})

module.exports = {
  karstSchema,
}
