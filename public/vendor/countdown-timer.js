var CountDownTimer;

CountDownTimer = function(duration, granularity) {
  this.duration = duration;
  this.granularity = granularity || 1000;
  this.tickFtns = [];
  this.running = false;
};

CountDownTimer.prototype.setDur = function(dur){
  this.duration = dur
}

CountDownTimer.prototype.start = function() {
  var diff, obj, start, that;
  if (this.running) {
    return;
  }
  this.running = true;
  start = Date.now();
  that = this;
  diff = void 0;
  obj = void 0;
  (function timer() {
    diff = that.duration - ((Date.now() - start) / 1000 | 0);
    if (diff > 0) {
      that.t = setTimeout(timer, that.granularity);
    } else {
      diff = 0;
      that.running = false;
    }
    obj = CountDownTimer.parse(diff);
    that.tickFtns.forEach((function(ftn) {
      ftn.call(this, obj.minutes, obj.seconds);
    }), that);
  })();
};

CountDownTimer.prototype.pause = function(){
  clearTimeout(this.t)
  this.running = false
}

CountDownTimer.prototype.onTick = function(ftn) {
  if (typeof ftn === 'function') {
    this.tickFtns.push(ftn);
  }
  return this;
};

CountDownTimer.prototype.expired = function() {
  return !this.running;
};

CountDownTimer.parse = function(seconds) {
  return {
    'minutes': seconds / 60 | 0,
    'seconds': seconds % 60 | 0
  };
};


