const Joi = require('joi')
const bluebird = require('bluebird')

const chainSchema = Joi.object({
  name: Joi.string().required()
})

module.exports = {
  chainSchema,
}
