-- Create a new database for sensor data
CREATE DATABASE IF NOT EXISTS `sensor` /*!40100 DEFAULT CHARACTER SET utf8mb4 */;

-- Use the sensor database
USE `sensor`;

-- Create the sensor_reading table
CREATE TABLE IF NOT EXISTS `sensor_reading` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `sensor_id` varchar(255) NOT NULL,
  `temperature` float NOT NULL,
  `humidity` float DEFAULT NULL,
  `input_time` datetime DEFAULT current_timestamp(),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
