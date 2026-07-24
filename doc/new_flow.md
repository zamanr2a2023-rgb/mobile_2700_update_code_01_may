Instructions for the mobile app developer 
Please update the mobile invitation flow to match the web app using the existing shared APIs.
Companies must be able to invite both existing mechanics and new users by email.
Use the API response field existingAccount to decide the flow.
Existing mechanic:
Show the invitation inside the app.
Load invitations using GET /api/v1/users/me/company-invites.
Allow accept or decline using the invitation ID.
After acceptance, refresh the user profile, role, company membership, permissions, and navigation.
Existing users must log in and accept the invitation. They must not register again using the invite token.
New user:
Open the invitation link using deep linking.
Read the email and inviteToken.
Validate the invitation before registration.
Register as MECHANIC_EMPLOYEE using the invite token.
Store the returned tokens and redirect to the correct dashboard.
Also handle pending, accepted, declined, cancelled, expired, invalid, and already-used invitations.
Keep all validation, role changes, and company-membership logic on the backend. Do not change unrelated mobile functionality.

Cursor prompt for the mobile app 

Prompt 1 — Run in Cursor Plan Mode
This is a planning and codebase-investigation task only.
Do not create, edit, delete, rename, move, or format any files.
Do not implement code.
Do not run migrations, code generators, package upgrades, or commands that modify the project.
Inspect the existing mobile application and create a complete implementation plan for updating the company-to-mechanic invitation flow so that it matches the existing web application and uses the current shared backend API.
Required business behavior
The mobile application must support invitations for both:
Existing independent mechanics who already have an account.
New mechanics who do not yet have an account.

Flow A — Existing independent mechanic
When a company invites an email address that belongs to an existing user with the MECHANIC role:
The company sends the invitation using:
POST /api/v1/company/team/invitations
Request payload:
{
  "email": "mechanic@example.com"
}


The existing mechanic must receive and see the invitation inside the mobile application.
Pending invitations must be loaded using:
GET /api/v1/users/me/company-invites
The mobile application must provide a pending invitations screen showing available information such as:
Company name
Invitation status
Expiration date
Accept action
Decline action
The mechanic accepts an invitation using:
POST /api/v1/users/me/company-invites/{inviteId}/accept
The mechanic declines an invitation using:
POST /api/v1/users/me/company-invites/{inviteId}/decline
After a successful acceptance, the application must:
Use the user object returned by the API.
Refresh the authenticated user profile.
Refresh the user role.
Refresh company membership.
Refresh permissions and feature access.
Refresh role-based navigation.
Redirect the user to the correct employee-mechanic area.
Prevent the same invitation from being accepted again.
Existing mechanics must accept invitations through their authenticated account using the invitation ID.
Existing mechanics must not use the invitation-registration token flow.

Flow B — New mechanic without an account
When a company invites an email address that does not belong to an existing user:
The mobile application must support opening the invitation through Android and iOS deep linking, if deep linking already exists or can be added safely.
The invitation link may include:
email
inviteToken
role
Before showing registration, validate the invitation using:
GET /api/v1/public/invites/validate?token={inviteToken}&email={email}
If the invitation is valid:
Show the inviting company name.
Prefill the invited email.
Prevent the invited email from being changed unless the backend supports changing it.
Show the employee-mechanic registration form.
Register the new employee mechanic using:
POST /api/v1/auth/register
Required payload:
{
  "email": "mechanic@example.com",
  "password": "password",
  "confirmPassword": "password",
  "role": "MECHANIC_EMPLOYEE",
  "inviteToken": "invitation-token",
  "fullName": "Mechanic Name",
  "phone": "phone-number"
}


After successful registration:
Securely store the access token.
Securely store the refresh token.
Save the returned user data.
Follow the returned nextStep.
Navigate to profile completion when required.
Otherwise navigate to the employee-mechanic dashboard.
If invitation validation returns existingAccount: true:
Do not allow the user to register again.
Redirect the user to login.
After login, navigate to the pending company invitations screen.

Company-side mobile behavior
Inspect the current company/admin invitation flow and plan the changes required to support both existing and new mechanics.
The company invitation request must use:
POST /api/v1/company/team/invitations
The response may contain:
existingAccount
inviteToken
signupUrl
emailSent
expiresAt
status
Required behavior:
When existingAccount is true
Inform the company that the mechanic already has an account.
Explain that the invitation will appear in the mechanic’s application.
Do not present the registration link as the primary action.
When existingAccount is false
Show the signup invitation link.
Allow the company to copy or share the invitation link.
When emailSent is false
Clearly inform the company that the email was not sent.
Still allow the invitation link to be copied or shared.
Inspect whether the mobile application already supports:
Resending an invitation:
POST /api/v1/company/team/invitations/{inviteId}/resend
Cancelling an invitation:
DELETE /api/v1/company/team/invitations/{inviteId}
Loading company team members and invitations:
GET /api/v1/company/team

Push-notification behavior
Inspect the current push-notification implementation.
The mobile application must support the notification type:
COMPANY_INVITE_RECEIVED
When the mechanic taps this notification, the intended behavior is:
Confirm whether the user is authenticated.
Navigate to the pending company invitations screen.
Refresh the invitation list.
Highlight the matching invitation when an inviteId is available and the current architecture supports it.

Required UI and application states
The implementation plan must include handling for:
Loading
Empty invitation list
Pending
Accepting
Declining
Accepted
Declined
Cancelled
Expired
Invalid token
Invitation not found
Already accepted
Existing account detected
Duplicate pending invitation
Network error
Unauthorized session
Email delivery failure
Use expiresAt when determining whether an invitation is expired.
Do not assume that the backend always stores the status as EXPIRED.

Architecture and security rules
The future implementation must:
Reuse the existing API client.
Reuse the existing authentication interceptor.
Reuse the existing state-management architecture.
Reuse the existing navigation architecture.
Include the Bearer token for authenticated endpoints.
Keep invitation validation on the backend.
Keep membership creation on the backend.
Never create company membership locally.
Never change the user role locally unless confirmed by the backend response.
Never invent new backend endpoints.
Never duplicate backend business rules inside the mobile app.
Never expose invitation tokens in logs.
Never store invitation tokens in plain-text logs.
Avoid unnecessarily passing invitation tokens between multiple screens.
Avoid changing unrelated screens, routes, models, services, or features.

Important backend limitation
The backend currently has an unresolved case involving users who already have the MECHANIC_EMPLOYEE role but have an inactive company membership.
Do not plan a mobile-only workaround for this case.
Clearly document:
Where this case affects the mobile flow.
What backend change may be required.
Which mobile behavior should be shown until the backend issue is resolved.

Investigation requirements
Inspect the actual mobile codebase and identify:
The current invitation flow.
Existing invitation models.
Existing invitation API services.
Authentication and token-storage implementation.
User model and role handling.
Company-membership handling.
State-management solution.
Role-based navigation.
Existing registration flow.
Existing company team-management screens.
Existing mechanic dashboard/profile screens.
Existing deep-link handling.
Android deep-link configuration.
iOS universal-link or deep-link configuration.
Existing push-notification handling.
Existing error-handling patterns.
Existing reusable UI components.
Existing tests related to authentication, registration, invitations, or navigation.
Do not assume the architecture.
Confirm findings from the actual mobile code.

Required output
Return a planning report containing:
1. Current mobile flow
Explain how invitations currently work in the mobile application.
2. Relevant files
Provide exact paths for all relevant:
Screens
Widgets or components
Models
API services
Repositories
Controllers, providers, blocs, cubits, stores, or view models
Authentication files
Navigation files
Deep-link files
Notification files
Registration files
Company-management files
3. Gap analysis
Explain the exact differences between:
The current mobile invitation flow
The required web-compatible invitation flow
4. API mapping
Provide a table containing:
HTTP method
Endpoint
Purpose
Authentication requirement
Request payload
Expected response fields
Mobile file that should call it
5. File-by-file implementation plan
For every file:
State whether it will be created or modified.
Explain the exact intended change.
Explain which existing architecture or pattern should be reused.
6. Batch-by-batch execution plan
Divide the implementation into small, testable batches.
Each batch must include:
Goal
Files expected to change
Features included
Features explicitly excluded
API endpoints included
Acceptance criteria
Automated checks
Manual testing steps
Risks and dependencies
Recommended batch structure:
Batch 1: API foundation and existing mechanic invitation flow
Batch 2: New-user invitation validation, deep linking, and registration
Batch 3: Company-side invitation updates, sharing, resend, and cancellation
Batch 4: Push notifications, edge cases, regression testing, and cleanup
You may adjust the batches if the actual mobile architecture makes another division safer.
7. Risks and regressions
Identify risks involving:
Authentication
Token storage
User-role changes
Company membership
Navigation
Existing registration
Deep linking
Push notifications
Existing company features
Existing mechanic features
8. Testing plan
Include tests for:
Company invites an existing mechanic.
Existing mechanic sees the invitation.
Existing mechanic accepts the invitation.
Existing mechanic declines the invitation.
User profile and role refresh after acceptance.
Navigation changes correctly after acceptance.
Company invites a new email.
New user opens the invitation link.
Valid invitation registration succeeds.
Invalid invitation is rejected.
Expired invitation is rejected.
Cancelled invitation is rejected.
Already accepted invitation is rejected.
Existing account is redirected to login.
Push notification opens the correct screen.
Email delivery failure still permits link sharing.
Duplicate invitation responses are handled.
No unrelated functionality is affected.
Final restriction
This is a planning task only.
Do not implement anything.
Do not modify any file.
Stop after presenting the complete investigation and implementation plan.
 



Run in Cursor Agent Mode for Each Batch 

Execute only Batch [BATCH NUMBER] from the approved company-to-mechanic invitation implementation plan.
Here are the approved details for this batch:
[PASTE BATCH DETAILS FROM THE APPROVED PLAN]
Do not implement any other batch.
Before editing code, briefly confirm:
The goal of this batch.
The files expected to change.
The API endpoints included.
The acceptance criteria.
Then implement only this batch.
Implementation requirements
Follow the existing mobile application architecture.
Reuse the existing API client.
Reuse the existing authentication interceptor.
Reuse the existing state-management pattern.
Reuse the existing navigation pattern.
Reuse existing models and UI components where appropriate.
Modify only the files required for this batch.
Create new files only when required by the approved plan.
Do not begin the next batch.
Do not modify unrelated screens or functionality.
Do not invent new API endpoints.
Do not change backend API contracts.
Do not reproduce backend business logic inside the mobile application.
Do not create company membership locally.
Do not change the user role unless confirmed by the API response.
Do not expose invitation tokens in logs.
Do not add a mobile-only workaround for inactive former MECHANIC_EMPLOYEE users.
Preserve existing visual and architectural conventions.
Keep changes small and reviewable.
Validation requirements
After implementation:
Format the modified files.
Run static analysis or linting.
Run relevant automated tests.
Run an available debug build or compilation check.
Fix errors introduced by this batch.
Do not hide or suppress unrelated pre-existing errors.
Verify every acceptance criterion for this batch.
Confirm that the project still follows the existing architecture.
Completion report
When this batch is complete, stop and report:
Files created.
Files modified.
What was implemented.
API endpoints connected.
Acceptance criteria completed.
Formatting, analysis, build, and tests performed.
Results of those checks.
Remaining issues.
Backend dependencies or limitations.
Manual testing instructions.
Anything that must be completed in a later batch.
Do not proceed to the next batch.


Exact workflow
Run Prompt 1 in Plan Mode.
Review the plan and batches.
Create a Git checkpoint.
Switch to Agent Mode.
Run Prompt 2 for Batch 1.
Review and test Batch 1.
Commit Batch 1.
Repeat Prompt 2 for each remaining batch.

