const Joi = require('joi')
const bluebird = require('bluebird')

const chainSchema = Joi.object({
  base_path: Joi.string().required(),
  name: Joi.string().regex(/^[0-9a-zA-Z_]+$/).required(),
  port: Joi.number().port().default(30333),
  rpc_port: Joi.number().port().default(9933),
  ws_port: Joi.number().port().default(9944),
})

module.exports = {
  chainSchema,
}
