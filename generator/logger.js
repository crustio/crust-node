//
// logger utils
const winston = require('winston')

const logger = winston.createLogger({
  level: 'debug',
  format: winston.format.simple(),
})

logger.add(new winston.transports.Console({
  format: winston.format.combine(
    winston.format.colorize(),
    winston.format.splat(),
    winston.format.simple()
  )
}))

module.exports = {
  logger,
}
