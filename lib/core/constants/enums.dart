/// Visibility levels for trips and content
enum Visibility {
  /// Only the owner can view
  private,

  /// Followers or users with a shared link can view
  protected,

  /// Everyone can view
  public;

  /// Convert visibility to string for API
  String toJson() {
    switch (this) {
      case Visibility.private:
        return 'PRIVATE';
      case Visibility.protected:
        return 'PROTECTED';
      case Visibility.public:
        return 'PUBLIC';
    }
  }

  /// Parse visibility from API response
  static Visibility fromJson(String value) {
    switch (value.toUpperCase()) {
      case 'PRIVATE':
        return Visibility.private;
      case 'PROTECTED':
        return Visibility.protected;
      case 'PUBLIC':
        return Visibility.public;
      default:
        throw ArgumentError('Invalid visibility value: $value');
    }
  }
}

/// Weather conditions from backend weather API (Google Weather API)
enum WeatherCondition {
  clear,
  mostlyClear,
  partlyCloudy,
  mostlyCloudy,
  cloudy,
  windy,
  windAndRain,
  lightRainShowers,
  chanceOfShowers,
  scatteredShowers,
  rainShowers,
  heavyRainShowers,
  lightToModerateRain,
  moderateToHeavyRain,
  rain,
  lightRain,
  heavyRain,
  rainPeriodicallyHeavy,
  lightSnowShowers,
  chanceOfSnowShowers,
  scatteredSnowShowers,
  snowShowers,
  heavySnowShowers,
  lightToModerateSnow,
  moderateToHeavySnow,
  snow,
  lightSnow,
  heavySnow,
  snowstorm,
  snowPeriodicallyHeavy,
  heavySnowStorm,
  blowingSnow,
  rainAndSnow,
  hail,
  hailShowers,
  thunderstorm,
  thundershower,
  lightThunderstormRain,
  scatteredThunderstorms,
  heavyThunderstorm,
  unknown;

  /// Convert weather condition to string for API
  String toJson() {
    switch (this) {
      case WeatherCondition.clear:
        return 'CLEAR';
      case WeatherCondition.mostlyClear:
        return 'MOSTLY_CLEAR';
      case WeatherCondition.partlyCloudy:
        return 'PARTLY_CLOUDY';
      case WeatherCondition.mostlyCloudy:
        return 'MOSTLY_CLOUDY';
      case WeatherCondition.cloudy:
        return 'CLOUDY';
      case WeatherCondition.windy:
        return 'WINDY';
      case WeatherCondition.windAndRain:
        return 'WIND_AND_RAIN';
      case WeatherCondition.lightRainShowers:
        return 'LIGHT_RAIN_SHOWERS';
      case WeatherCondition.chanceOfShowers:
        return 'CHANCE_OF_SHOWERS';
      case WeatherCondition.scatteredShowers:
        return 'SCATTERED_SHOWERS';
      case WeatherCondition.rainShowers:
        return 'RAIN_SHOWERS';
      case WeatherCondition.heavyRainShowers:
        return 'HEAVY_RAIN_SHOWERS';
      case WeatherCondition.lightToModerateRain:
        return 'LIGHT_TO_MODERATE_RAIN';
      case WeatherCondition.moderateToHeavyRain:
        return 'MODERATE_TO_HEAVY_RAIN';
      case WeatherCondition.rain:
        return 'RAIN';
      case WeatherCondition.lightRain:
        return 'LIGHT_RAIN';
      case WeatherCondition.heavyRain:
        return 'HEAVY_RAIN';
      case WeatherCondition.rainPeriodicallyHeavy:
        return 'RAIN_PERIODICALLY_HEAVY';
      case WeatherCondition.lightSnowShowers:
        return 'LIGHT_SNOW_SHOWERS';
      case WeatherCondition.chanceOfSnowShowers:
        return 'CHANCE_OF_SNOW_SHOWERS';
      case WeatherCondition.scatteredSnowShowers:
        return 'SCATTERED_SNOW_SHOWERS';
      case WeatherCondition.snowShowers:
        return 'SNOW_SHOWERS';
      case WeatherCondition.heavySnowShowers:
        return 'HEAVY_SNOW_SHOWERS';
      case WeatherCondition.lightToModerateSnow:
        return 'LIGHT_TO_MODERATE_SNOW';
      case WeatherCondition.moderateToHeavySnow:
        return 'MODERATE_TO_HEAVY_SNOW';
      case WeatherCondition.snow:
        return 'SNOW';
      case WeatherCondition.lightSnow:
        return 'LIGHT_SNOW';
      case WeatherCondition.heavySnow:
        return 'HEAVY_SNOW';
      case WeatherCondition.snowstorm:
        return 'SNOWSTORM';
      case WeatherCondition.snowPeriodicallyHeavy:
        return 'SNOW_PERIODICALLY_HEAVY';
      case WeatherCondition.heavySnowStorm:
        return 'HEAVY_SNOW_STORM';
      case WeatherCondition.blowingSnow:
        return 'BLOWING_SNOW';
      case WeatherCondition.rainAndSnow:
        return 'RAIN_AND_SNOW';
      case WeatherCondition.hail:
        return 'HAIL';
      case WeatherCondition.hailShowers:
        return 'HAIL_SHOWERS';
      case WeatherCondition.thunderstorm:
        return 'THUNDERSTORM';
      case WeatherCondition.thundershower:
        return 'THUNDERSHOWER';
      case WeatherCondition.lightThunderstormRain:
        return 'LIGHT_THUNDERSTORM_RAIN';
      case WeatherCondition.scatteredThunderstorms:
        return 'SCATTERED_THUNDERSTORMS';
      case WeatherCondition.heavyThunderstorm:
        return 'HEAVY_THUNDERSTORM';
      case WeatherCondition.unknown:
        return 'UNKNOWN';
    }
  }

  /// Parse weather condition from API response
  static WeatherCondition fromJson(String value) {
    switch (value.toUpperCase()) {
      case 'CLEAR':
        return WeatherCondition.clear;
      case 'MOSTLY_CLEAR':
        return WeatherCondition.mostlyClear;
      case 'PARTLY_CLOUDY':
        return WeatherCondition.partlyCloudy;
      case 'MOSTLY_CLOUDY':
        return WeatherCondition.mostlyCloudy;
      case 'CLOUDY':
        return WeatherCondition.cloudy;
      case 'WINDY':
        return WeatherCondition.windy;
      case 'WIND_AND_RAIN':
        return WeatherCondition.windAndRain;
      case 'LIGHT_RAIN_SHOWERS':
        return WeatherCondition.lightRainShowers;
      case 'CHANCE_OF_SHOWERS':
        return WeatherCondition.chanceOfShowers;
      case 'SCATTERED_SHOWERS':
        return WeatherCondition.scatteredShowers;
      case 'RAIN_SHOWERS':
        return WeatherCondition.rainShowers;
      case 'HEAVY_RAIN_SHOWERS':
        return WeatherCondition.heavyRainShowers;
      case 'LIGHT_TO_MODERATE_RAIN':
        return WeatherCondition.lightToModerateRain;
      case 'MODERATE_TO_HEAVY_RAIN':
        return WeatherCondition.moderateToHeavyRain;
      case 'RAIN':
        return WeatherCondition.rain;
      case 'LIGHT_RAIN':
        return WeatherCondition.lightRain;
      case 'HEAVY_RAIN':
        return WeatherCondition.heavyRain;
      case 'RAIN_PERIODICALLY_HEAVY':
        return WeatherCondition.rainPeriodicallyHeavy;
      case 'LIGHT_SNOW_SHOWERS':
        return WeatherCondition.lightSnowShowers;
      case 'CHANCE_OF_SNOW_SHOWERS':
        return WeatherCondition.chanceOfSnowShowers;
      case 'SCATTERED_SNOW_SHOWERS':
        return WeatherCondition.scatteredSnowShowers;
      case 'SNOW_SHOWERS':
        return WeatherCondition.snowShowers;
      case 'HEAVY_SNOW_SHOWERS':
        return WeatherCondition.heavySnowShowers;
      case 'LIGHT_TO_MODERATE_SNOW':
        return WeatherCondition.lightToModerateSnow;
      case 'MODERATE_TO_HEAVY_SNOW':
        return WeatherCondition.moderateToHeavySnow;
      case 'SNOW':
        return WeatherCondition.snow;
      case 'LIGHT_SNOW':
        return WeatherCondition.lightSnow;
      case 'HEAVY_SNOW':
        return WeatherCondition.heavySnow;
      case 'SNOWSTORM':
        return WeatherCondition.snowstorm;
      case 'SNOW_PERIODICALLY_HEAVY':
        return WeatherCondition.snowPeriodicallyHeavy;
      case 'HEAVY_SNOW_STORM':
        return WeatherCondition.heavySnowStorm;
      case 'BLOWING_SNOW':
        return WeatherCondition.blowingSnow;
      case 'RAIN_AND_SNOW':
        return WeatherCondition.rainAndSnow;
      case 'HAIL':
        return WeatherCondition.hail;
      case 'HAIL_SHOWERS':
        return WeatherCondition.hailShowers;
      case 'THUNDERSTORM':
        return WeatherCondition.thunderstorm;
      case 'THUNDERSHOWER':
        return WeatherCondition.thundershower;
      case 'LIGHT_THUNDERSTORM_RAIN':
        return WeatherCondition.lightThunderstormRain;
      case 'SCATTERED_THUNDERSTORMS':
        return WeatherCondition.scatteredThunderstorms;
      case 'HEAVY_THUNDERSTORM':
        return WeatherCondition.heavyThunderstorm;
      default:
        return WeatherCondition.unknown;
    }
  }
}

/// Status for trips
enum TripStatus {
  /// Trip is being created
  created,

  /// Trip is currently ongoing
  inProgress,

  /// Trip is paused
  paused,

  /// Trip has finished
  finished,

  /// Pilgrim has finished the day's stage and is resting overnight
  resting;

  /// Human-readable label for display
  String get displayLabel {
    switch (this) {
      case TripStatus.created:
        return 'Created';
      case TripStatus.inProgress:
        return 'In Progress';
      case TripStatus.paused:
        return 'Paused';
      case TripStatus.finished:
        return 'Finished';
      case TripStatus.resting:
        return 'Resting';
    }
  }

  /// Convert status to string for API
  String toJson() {
    switch (this) {
      case TripStatus.created:
        return 'CREATED';
      case TripStatus.inProgress:
        return 'IN_PROGRESS';
      case TripStatus.paused:
        return 'PAUSED';
      case TripStatus.finished:
        return 'FINISHED';
      case TripStatus.resting:
        return 'RESTING';
    }
  }

  /// Parse status from API response
  static TripStatus fromJson(String value) {
    switch (value.toUpperCase()) {
      case 'CREATED':
        return TripStatus.created;
      case 'IN_PROGRESS':
        return TripStatus.inProgress;
      case 'PAUSED':
        return TripStatus.paused;
      case 'FINISHED':
        return TripStatus.finished;
      case 'RESTING':
        return TripStatus.resting;
      default:
        throw ArgumentError('Invalid trip status value: $value');
    }
  }
}

/// Sort order for a trip's comments list (UI-only, no backend serialization)
enum CommentSortOption { latest, oldest, mostReplies, mostReactions }

/// Type of trip update/location entry
enum TripUpdateType {
  /// A regular location update
  regular,

  /// Marks the beginning of a new day in a multi-day trip
  dayStart,

  /// Marks the end of a day in a multi-day trip
  dayEnd,

  /// Marks the very start of the trip
  tripStarted,

  /// Marks the very end of the trip
  tripEnded;

  /// Human-readable label for display
  String get displayLabel {
    switch (this) {
      case TripUpdateType.regular:
        return 'Update';
      case TripUpdateType.dayEnd:
        return 'Day End';
      case TripUpdateType.dayStart:
        return 'Day Start';
      case TripUpdateType.tripStarted:
        return 'Trip Started';
      case TripUpdateType.tripEnded:
        return 'Trip Ended';
    }
  }

  /// Convert type to string for API
  String toJson() {
    switch (this) {
      case TripUpdateType.regular:
        return 'REGULAR';
      case TripUpdateType.dayEnd:
        return 'DAY_END';
      case TripUpdateType.dayStart:
        return 'DAY_START';
      case TripUpdateType.tripStarted:
        return 'TRIP_STARTED';
      case TripUpdateType.tripEnded:
        return 'TRIP_ENDED';
    }
  }

  /// Parse type from API response
  static TripUpdateType fromJson(String value) {
    switch (value.toUpperCase()) {
      case 'DAY_END':
        return TripUpdateType.dayEnd;
      case 'DAY_START':
        return TripUpdateType.dayStart;
      case 'TRIP_STARTED':
        return TripUpdateType.tripStarted;
      case 'TRIP_ENDED':
        return TripUpdateType.tripEnded;
      case 'REGULAR':
      default:
        return TripUpdateType.regular;
    }
  }
}

/// Modality for a trip
enum TripModality {
  /// A single-day trip
  simple,

  /// A multi-day trip
  multiDay;

  /// Human-readable label for display
  String get displayLabel {
    switch (this) {
      case TripModality.simple:
        return 'Simple';
      case TripModality.multiDay:
        return 'Multi-Day';
    }
  }

  /// Convert modality to string for API
  String toJson() {
    switch (this) {
      case TripModality.simple:
        return 'SIMPLE';
      case TripModality.multiDay:
        return 'MULTI_DAY';
    }
  }

  /// Parse modality from API response
  static TripModality fromJson(String value) {
    switch (value.toUpperCase()) {
      case 'SIMPLE':
        return TripModality.simple;
      case 'MULTI_DAY':
        return TripModality.multiDay;
      default:
        throw ArgumentError('Invalid trip modality value: $value');
    }
  }
}
