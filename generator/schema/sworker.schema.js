
const Joi = require('joi')

const sworkerSchema = Joi.object({
  base_path: Joi.string().required(),
  srd_paths: Joi.array().items(Joi.string()).required(),
  srd_init_capacity: Joi.number().positive().integer().default(1),
  port: Joi.number().port().default(12222),
})

module.exports = {
  sworkerSchema,
}
