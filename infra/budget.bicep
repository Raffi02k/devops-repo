param amount int
param contactEmail string

resource budget 'Microsoft.Consumption/budgets@2024-08-01' = {
  name: 'budget-early-warning'
  properties: {
    category: 'Cost'
    amount: amount
    timeGrain: 'Annually'
    timePeriod: {
      startDate: '2026-10-01'
      endDate: '2026-12-31'
    }
    notifications: {
      halfUsed: {
        enabled: true
        operator: 'GreaterThanOrEqualTo'
        threshold: 50
        thresholdType: 'Actual'
        contactEmails: [
          contactEmail
        ]
      }
      onTrackToRunOut: {
        enabled: true
        operator: 'GreaterThan'
        threshold: 100
        thresholdType: 'Forecasted'
        contactEmails: [
          contactEmail
        ]
      }
    }
  }
}
