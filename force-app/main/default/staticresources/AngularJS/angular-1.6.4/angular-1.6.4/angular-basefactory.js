BaseFactory.$inject = ['$q', '$rootScope'];

function BaseFactory($q, $rootScope) {
    var factory = {};
    factory.callRemoteActionWithParameter = function (remoteAction, parameter) {
        var deferred = $q.defer();
        Visualforce.remoting.Manager.invokeAction(remoteAction, parameter, function (result) {
            $rootScope.$apply(function () {
                deferred.resolve(result);
            });
        }, {
            escape: false
        });

        return deferred.promise;
    }
    // call remote action without parameter
    factory.callRemoteActionWithoutParameter = function (remoteAction) {
        var deferred = $q.defer();
        Visualforce.remoting.Manager.invokeAction(remoteAction, function (result) {
            $rootScope.$apply(function () {
                deferred.resolve(result);
            });
        }, {
            escape: false
        });
        return deferred.promise;
    }
    return factory;
};

CustomStorage = {
    save: function (key, jsonData, expirationMin) {
        var expirationMS = expirationMin * 60 * 1000;
        var record = {
            value: JSON.stringify(jsonData),
            timestamp: new Date().getTime() + expirationMS
        }
        localStorage.setItem(key, JSON.stringify(record));
        return jsonData;
    },
    load: function (key) {
        if (!localStorage.getItem(key)) {
            return false;
        }
        var record = JSON.parse(localStorage.getItem(key));
        if (!record) {
            return false;
        }
        if (new Date().getTime() > record.timestamp) {
            localStorage.removeItem(key);
        }
        return (new Date().getTime() < record.timestamp && JSON.parse(record.value));
    }
}