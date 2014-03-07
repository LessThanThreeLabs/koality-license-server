var app = angular.module('myApp', ["trNgGrid"]);

app.controller('LicenseViewerController', ['$scope', '$http', function($scope, $http) {
	$http({
		method:'GET',
		url:'licenses'
	}).success(function(data, status, headers, config) {
		var licensesMap = {};
		for (var i=0; i<data.length; i++) {
			var license = data[i];
			if (license.lastPing) {
				license.lastPing *= 1000;
			}

			license.isValid = !!license.isValid;

			var storedLicense = licensesMap[license.id];
			if (!storedLicense) {
				licensesMap[license.id] = license;
				storedLicense = license;
			}
			if (license.metadataName) {
				storedLicense[license.metadataName] = parseInt(license.metadataValue, 10) || license.metadataValue;
			}
			if (license.permissionName) {
				storedLicense[license.permissionName] = parseInt(license.permissionValue, 10) || license.permissionValue;
			}

			delete storedLicense.metadataName;
			delete storedLicense.metadataValue;
			delete storedLicense.permissionName;
			delete storedLicense.permissionValue;
			delete storedLicense.accountId;
			delete storedLicense.stripeCustomerId;
			delete storedLicense.unpaidExpiration;
		}

		var licenses = [];
		for (var id in licensesMap) {
			licenses.push(licensesMap[id]);
		}
		$scope.licenses = licenses;
	});
}]);
