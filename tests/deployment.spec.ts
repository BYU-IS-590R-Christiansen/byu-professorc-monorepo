import { test, expect, Page, APIRequestContext } from "@playwright/test";

// Type declaration for process.env
declare const process: {
	env: {
		[key: string]: string | undefined;
	};
};

const BACKEND_URL = process.env.BACKEND_URL || "http://localhost:4444";
const FRONTEND_URL = process.env.FRONTEND_URL || "http://localhost";

test.describe("Deployment Verification", () => {
	test("Laravel landing page should load", async ({ page }: { page: Page }) => {
		await page.goto(`${BACKEND_URL}/`);

		// Check that the page loads successfully (status 200)
		expect(page.url()).toContain(BACKEND_URL);

		// Laravel welcome page should contain some Laravel-specific content
		// Common Laravel welcome page elements
		const bodyText = await page.textContent("body");
		expect(bodyText).toBeTruthy();

		// Verify we get a valid HTML response (not an error page)
		const title = await page.title();
		expect(title).toBeTruthy();

		// Check for common Laravel welcome page indicators
		// The welcome page might have "Laravel" text or a simple welcome message
		const pageContent = await page.content();
		expect(pageContent.length).toBeGreaterThan(0);

		// Take a screenshot for verification
		await page.screenshot({
			path: "test-results/laravel-landing.png",
			fullPage: true,
		});
	});

	test("Frontend login page should show the sign-in form", async ({
		page,
	}: {
		page: Page;
	}) => {
		// Navigate to the frontend URL (should show login page)
		await page.goto(FRONTEND_URL);

		// Wait for the page to load
		await page.waitForLoadState("networkidle");

		const loginTitle = page.getByRole("heading", {
			name: "Welcome back",
			exact: true,
		});
		await expect(loginTitle).toBeVisible({ timeout: 10000 });

		const loginButton = page.getByRole("button", { name: "Sign in" });
		await expect(loginButton).toBeVisible({ timeout: 10000 });

		// Verify login form elements are present
		const emailInput = page.getByLabel("Email");
		await expect(emailInput).toBeVisible();

		const passwordInput = page.getByLabel("Password");
		await expect(passwordInput).toBeVisible();

		// Take a screenshot for verification
		await page.screenshot({
			path: "test-results/login-page.png",
			fullPage: true,
		});
	});

	test("Backend API health endpoint should respond", async ({
		request,
	}: {
		request: APIRequestContext;
	}) => {
		const response = await request.get(`${BACKEND_URL}/api/health`);
		expect(response.ok()).toBeTruthy();
		expect(response.status()).toBe(200);
	});

	test("Backend API hello endpoint should respond with correct message", async ({
		request,
	}: {
		request: APIRequestContext;
	}) => {
		const response = await request.get(`${BACKEND_URL}/api/hello`);
		expect(response.ok()).toBeTruthy();
		expect(response.status()).toBe(200);

		const body = await response.json();
		expect(body).toBeTruthy();

		// Verify the exact message from the API
		expect(body.message).toBe("Hello World from BYU 590R Monorepo!");
		expect(body.status).toBe("success");
		expect(body.timestamp).toBeTruthy();
	});

	test("Backend API login endpoint should accept POST requests", async ({
		request,
	}: {
		request: APIRequestContext;
	}) => {
		// Test that login endpoint exists and responds (even if credentials are wrong)
		const response = await request.post(`${BACKEND_URL}/api/login`, {
			data: {
				email: "test@example.com",
				password: "wrongpassword",
			},
		});

		// Should respond (even if unauthorized)
		expect(response.status()).toBeTruthy();

		// Should return JSON response (API returns JSON, not HTML)
		const contentType = response.headers()["content-type"] || "";
		const text = await response.text();
		if (!contentType.includes("application/json")) {
			throw new Error(
				`Login endpoint returned non-JSON (status ${response.status()}). Body starts with: ${text.slice(0, 200)}`,
			);
		}
		const body = JSON.parse(text);
		expect(body).toBeTruthy();

		// If credentials are wrong, should have error message
		// If CORS is working, we should get a response (not CORS error)
		const corsHeader = response.headers()["access-control-allow-origin"];
		expect(corsHeader).toBeTruthy();
	});

	test("Backend API login should succeed with seeded test user credentials", async ({
		request,
	}: {
		request: APIRequestContext;
	}) => {
		// Test login with credentials from UsersSeeder
		// Email: testuser@test.com, Password: password12345
		const response = await request.post(`${BACKEND_URL}/api/login`, {
			data: {
				email: "testuser@test.com",
				password: "password12345",
			},
		});

		// Should succeed with valid credentials
		const text = await response.text();
		const contentType = response.headers()["content-type"] || "";
		if (!response.ok()) {
			throw new Error(
				`Login failed (status ${response.status()}). Content-Type: ${contentType}. Body: ${text.slice(0, 300)}`,
			);
		}
		expect(response.ok()).toBeTruthy();
		expect(response.status()).toBe(200);

		// Should return JSON response with success data
		if (!contentType.includes("application/json")) {
			throw new Error(
				`Login returned non-JSON. Body starts with: ${text.slice(0, 200)}`,
			);
		}
		const body = JSON.parse(text);
		expect(body).toBeTruthy();

		// Verify successful login response structure
		expect(body.success).toBe(true);
		expect(body.results).toBeTruthy();
		expect(body.results.token).toBeTruthy();
		expect(body.results.name).toBe("Test User");
		expect(body.message).toContain("login successfully");

		// Verify CORS headers are present
		const corsHeader = response.headers()["access-control-allow-origin"];
		expect(corsHeader).toBeTruthy();
	});
});
