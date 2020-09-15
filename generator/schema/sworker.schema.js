
const Joi = require('joi')

const sworkerSchema = Joi.object({
  srd_paths: Joi.array().items(Joi.string()).required(),
  srd_init_capacity: Joi.number().positive().integer().default(1),
})

module.exports = {
  sworkerSchema,
}
