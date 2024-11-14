param name string
param location string = resourceGroup().location
param tags object = {}
param subnetId string
param dnsLabelPrefix string
param frontendWebAppFqdn string
param privateLinkSubnetId string
param privateIp string

var resourceNames = {
  publicIP: 'pip-${name}'
  backendAddressPool: 'beap-frontendwebapp-${name}'
  frontendPort80: 'feport-${name}-80'
  frontendPrivateIpConfiguration: 'appGwPrivateFrontendIpIPv4'
  frontendPublicIpConfiguration: 'appGwPublicFrontendIpIPv4'
  backendHttpSettingFor443: 'be-htst-${name}-443'
  httpListener: 'httplstn-${name}'
  requestRoutingRule: 'rqrt-${name}'
  redirectConfiguration: 'rdrcfg-${name}'
  probeApimGateway: 'prb-apimgw-${name}-gw'
  probeApimPortal: 'prb-apimgw-${name}-portal'
  privateLinkConfiguration: 'hubai-dev-privatelink'
}

resource pip 'Microsoft.Network/publicIPAddresses@2020-06-01' = {
  name: resourceNames.publicIP
  location: location
  tags: tags
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    dnsSettings: {
      domainNameLabel: dnsLabelPrefix
    }
  }
}

resource applicationGateway 'Microsoft.Network/applicationGateways@2021-02-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'WAF_v2'
      tier: 'WAF_v2'
    }
    autoscaleConfiguration: {
      minCapacity: 1
      maxCapacity: 4
    }
    gatewayIPConfigurations: [
      {
        name: '${name}-ip-configuration'
        properties: {
          subnet: {
            id: subnetId
          }
        }
      }
    ]
    frontendIPConfigurations: [
      {
        name: resourceNames.frontendPublicIpConfiguration
        properties: {
          publicIPAddress: {
            id: pip.id
          }
        }
      }      
      {
        name: resourceNames.frontendPrivateIpConfiguration
        properties: {
          privateIPAllocationMethod: 'Static'
          subnet: {
            id: subnetId
          }
          privateIPAddress: privateIp
          privateLinkConfiguration: {
             id: resourceId('Microsoft.Network/applicationGateways/privateLinkConfigurations',name, resourceNames.privateLinkConfiguration)
          }
        }
      }
    ]
    frontendPorts: [
      {
        name: resourceNames.frontendPort80
        properties: {
          port: 80
        }
      }
    ]
    probes: [
      {
        name: resourceNames.probeApimGateway
        properties: {
          path: '/status-0123456789abcdef'
          pickHostNameFromBackendHttpSettings: true
          protocol: 'Https'
          timeout: 30
          interval: 30
        }
      }    
      {
        name: resourceNames.probeApimPortal
        properties: {
          path: '/signin'
          pickHostNameFromBackendHttpSettings: true
          protocol: 'Https'
          timeout: 30
          interval: 30
        }
      }
    ]      
    backendAddressPools: [
      {
        name: resourceNames.backendAddressPool
        properties: {
          backendAddresses: [
            {
              fqdn: frontendWebAppFqdn
            }
          ]
        }
      }
    ]
    backendHttpSettingsCollection: [
      {
        name: resourceNames.backendHttpSettingFor443
        properties: {
          port: 443
          protocol: 'Https'
          cookieBasedAffinity: 'Disabled'
          pickHostNameFromBackendAddress: true
          requestTimeout: 120
          probe: {
            id: resourceId('Microsoft.Network/applicationGateways/probes', name, resourceNames.probeApimGateway)
          }          
        }
      }
    ]
    httpListeners: [
      {
        name: resourceNames.httpListener
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendIPConfigurations', name, resourceNames.frontendPrivateIpConfiguration)
          }
          frontendPort: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendPorts', name, resourceNames.frontendPort80)
          }
          protocol: 'Http'
          sslCertificate: null
        }
      }
    ]
    requestRoutingRules: [
      {
        name: resourceNames.requestRoutingRule
        properties: {
          ruleType: 'Basic'
          httpListener: {
            id: resourceId('Microsoft.Network/applicationGateways/httpListeners', name, resourceNames.httpListener)
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/applicationGateways/backendAddressPools', name, resourceNames.backendAddressPool)
          }
          backendHttpSettings: {
            id: resourceId('Microsoft.Network/applicationGateways/backendHttpSettingsCollection', name, resourceNames.backendHttpSettingFor443)
          }
        }
      }
    ]
    privateLinkConfigurations: [
      {
        name: resourceNames.privateLinkConfiguration
        properties: {
          ipConfigurations: [
            {
              name: 'privateLinkIpConfig1'
              properties: {
                privateIPAllocationMethod: 'Dynamic'
                primary: false
                subnet: {
                  id: privateLinkSubnetId
                }
              }
            }
            {
              name: 'privateLinkIpConfig2'
              properties: {
                privateIPAllocationMethod: 'Dynamic'
                primary: false
                subnet: {
                  id: privateLinkSubnetId
                }
              }
            }
          ]
        }
      }
    ]
  }
}

output name string = applicationGateway.name
