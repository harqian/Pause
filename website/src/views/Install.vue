<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { supabase } from '../lib/supabase'

const router = useRouter()
const email = ref('')
const isEmailSubmitted = ref(false)
const emailError = ref('')
const emailInput = ref<HTMLInputElement | null>(null)
const isSubmitting = ref(false)
const showInstallPopup = ref(false)

onMounted(() => {
  // Autofocus the email input when component mounts
  setTimeout(() => {
    emailInput.value?.focus()
  }, 100)
})

const validateEmail = (email: string): boolean => {
  const re = /^[^\s@]+@[^\s@]+\.[^\s@]+$/
  return re.test(email)
}

const handleWaitlist = async () => {
  emailError.value = ''

  if (!email.value.trim()) {
    emailError.value = 'Please enter your email address'
    return
  }

  if (!validateEmail(email.value)) {
    emailError.value = 'Please enter a valid email address'
    return
  }

  isSubmitting.value = true

  const sendWelcomeEmail = async () => {
    const scriptUrl = import.meta.env.VITE_GOOGLE_SCRIPT_URL
    if (scriptUrl) {
      try {
        await fetch(scriptUrl, {
          method: 'POST',
          mode: 'no-cors',
          headers: {
            'Content-Type': 'text/plain',
          },
          body: JSON.stringify({ email: email.value.trim().toLowerCase() }),
        })
      } catch (err) {
        console.error('Email error:', err)
      }
    }
  }

  try {
    const { error } = await supabase
      .from('waitlist')
      .insert([{ email: email.value.trim().toLowerCase() }])

    if (error) {
      if (error.code === '23505') {
        // Duplicate email - still allow download and send email
        await sendWelcomeEmail()
        startDownload()
        isEmailSubmitted.value = true
        isSubmitting.value = false
        return
      } else {
        emailError.value = 'Something went wrong. Please try again.'
        console.error('Supabase error:', error)
        isSubmitting.value = false
        return
      }
    }

    // New email - send welcome email
    await sendWelcomeEmail()

    // Start download
    startDownload()
    isEmailSubmitted.value = true
  } catch (err) {
    emailError.value = 'Something went wrong. Please try again.'
    console.error('Error:', err)
    isSubmitting.value = false
  }
}

const startDownload = () => {
  const link = document.createElement('a')
  link.href = '/Pause.zip'
  link.download = 'Pause.zip'
  document.body.appendChild(link)
  link.click()
  document.body.removeChild(link)

  // Show installation instructions popup
  setTimeout(() => {
    showInstallPopup.value = true
  }, 500)
}

const closePopup = () => {
  showInstallPopup.value = false
}

const goHome = () => {
  router.push('/')
}
</script>

<template>
  <div class="install">
    <button @click="goHome" class="back-button">← Back</button>

    <div class="container">
      <h1 class="title">Get Pause</h1>

      <div v-if="!isEmailSubmitted" class="download-section">
        <p class="subtitle">Enter your email to download Pause</p>

        <div class="email-form">
          <input
            ref="emailInput"
            v-model="email"
            type="email"
            placeholder="your@email.com"
            class="email-input"
            :class="{ error: emailError }"
            @keyup.enter="handleWaitlist"
          />
          <button @click="handleWaitlist" class="download-button" :disabled="isSubmitting">
            {{ isSubmitting ? 'Downloading...' : 'Download' }}
          </button>
        </div>

        <p v-if="emailError" class="error-message">{{ emailError }}</p>

        <p class="privacy-note">
          I will send you one email with how to get started in terms of settings (which is genuinely
          useful, the settings are pretty confusing). I don't plan to send more emails unless it
          breaks in a catastrophic way.
        </p>
      </div>

      <div v-else class="success-section">
        <div class="success-icon">✓</div>
        <p class="success-message">Download started! Check your Downloads folder.</p>
      </div>

      <div class="info-box">
        <h2 class="info-title">What You'll Get</h2>
        <ul class="info-list">
          <li>Pause.app for macOS (Ventura 13.0+)</li>
          <li>Installation instructions</li>
          <li>Free forever, no subscriptions</li>
          <li>Open source and privacy-focused</li>
        </ul>
      </div>
    </div>

    <!-- Installation Instructions Popup -->
    <div v-if="showInstallPopup" class="popup-overlay" @click="closePopup">
      <div class="popup-content" @click.stop>
        <button class="close-button" @click="closePopup">×</button>
        <h2 class="popup-title">Installation Instructions</h2>
        <div class="downloads-guide">
          <p>Go to your downloads folder:</p>
          <img src="/downloads.png" alt="How to access Downloads folder" class="downloads-image" />
        </div>
        <ol class="install-steps">
          <li>Unzip the downloaded file</li>
          <li>Drag <strong>Pause.app</strong> to your <strong>Applications</strong> folder</li>
          <li>Launch Pause using Spotlight (⌘ + Space, then type "Pause")</li>
          <li>Grant accessibility permissions when prompted for global hotkey</li>
        </ol>
        <button @click="closePopup" class="got-it-button">Got it!</button>
      </div>
    </div>
  </div>
</template>

<style scoped>
.install {
  min-height: 100vh;
  height: 100vh;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  background: linear-gradient(
    135deg,
    rgb(151, 187, 101),
    rgb(198, 225, 116),
    rgb(215, 225, 199),
    rgb(198, 225, 116),
    rgb(151, 187, 101)
  );
  background-size: 400% 400%;
  animation: gradientShift 15s ease infinite;
  color: white;
  overflow: hidden;
  position: relative;
  padding: 2rem;
}

.back-button {
  position: absolute;
  top: 2rem;
  left: 2rem;
  background: rgba(255, 255, 255, 0.2);
  color: black;
  border: 2px solid black;
  padding: 0.75rem 1.5rem;
  border-radius: 8px;
  font-size: 1rem;
  font-weight: 600;
  cursor: pointer;
  transition: all 0.3s ease;
}

.back-button:hover {
  background: rgba(255, 255, 255, 0.3);
  transform: translateX(-3px);
}

.container {
  text-align: center;
  max-width: 700px;
  width: 100%;
}

.title {
  font-size: 3.5rem;
  font-weight: 700;
  margin-bottom: 2rem;
  letter-spacing: -0.02em;
  color: black;
}

.subtitle {
  font-size: 1.25rem;
  margin-bottom: 2rem;
  opacity: 0.95;
  color: black;
}

.download-section {
  margin-bottom: 3rem;
}

.email-form {
  display: flex;
  gap: 1rem;
  justify-content: center;
  margin-bottom: 0.5rem;
  flex-wrap: wrap;
}

.email-input {
  flex: 1;
  min-width: 250px;
  max-width: 400px;
  padding: 1rem 1.5rem;
  font-size: 1.1rem;
  border: 2px solid white;
  border-radius: 8px;
  background: rgba(255, 255, 255, 0.9);
  color: #333;
  transition: all 0.3s ease;
}

.email-input:focus {
  outline: none;
  background: white;
  box-shadow: 0 0 0 3px rgba(255, 255, 255, 0.3);
}

.email-input.error {
  border-color: #ff6b6b;
  background: #ffebee;
}

.download-button {
  padding: 1rem 2.5rem;
  font-size: 1.1rem;
  font-weight: 600;
  background: white;
  color: rgb(151, 187, 101);
  border: none;
  border-radius: 8px;
  cursor: pointer;
  transition: all 0.3s ease;
  box-shadow: 0 4px 15px rgba(0, 0, 0, 0.2);
  white-space: nowrap;
}

.download-button:hover:not(:disabled) {
  transform: translateY(-2px);
  box-shadow: 0 6px 20px rgba(0, 0, 0, 0.3);
}

.download-button:disabled {
  opacity: 0.6;
  cursor: not-allowed;
}

.error-message {
  color: #ffebee;
  font-size: 0.95rem;
  margin-top: 0.5rem;
  font-weight: 500;
}

.privacy-note {
  font-size: 0.9rem;
  opacity: 0.8;
  margin-top: 1rem;
  color: black;
}

.success-section {
  margin-bottom: 3rem;
}

.success-icon {
  font-size: 4rem;
  margin-bottom: 1rem;
  animation: scaleIn 0.5s ease-out;
}

.success-message {
  font-size: 1.25rem;
  animation: fadeIn 0.5s ease-out 0.2s backwards;
  color: black;
}

.info-box {
  background: rgba(255, 255, 255, 0.15);
  padding: 2rem;
  border-radius: 12px;
  margin-bottom: 2rem;
  backdrop-filter: blur(10px);
}

.info-title {
  font-size: 1.75rem;
  margin-bottom: 1.5rem;
  font-weight: 600;
  color: black;
}

.info-list {
  text-align: left;
  max-width: 500px;
  margin: 0 auto;
  line-height: 2;
  font-size: 1.05rem;
  list-style-type: none;
  padding-left: 0;
  color: black;
}

.info-list li {
  margin-bottom: 0.75rem;
  padding-left: 1.5rem;
  position: relative;
}

.info-list li::before {
  content: '•';
  position: absolute;
  left: 0;
  font-weight: bold;
}

@keyframes scaleIn {
  from {
    transform: scale(0);
    opacity: 0;
  }
  to {
    transform: scale(1);
    opacity: 1;
  }
}

@keyframes fadeIn {
  from {
    opacity: 0;
  }
  to {
    opacity: 1;
  }
}

@keyframes gradientShift {
  0% {
    background-position: 0% 50%;
  }
  50% {
    background-position: 100% 50%;
  }
  100% {
    background-position: 0% 50%;
  }
}

/* Popup Styles */
.popup-overlay {
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background: rgba(0, 0, 0, 0.7);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 1000;
  animation: fadeIn 0.3s ease;
}

.popup-content {
  background: white;
  padding: 2.5rem;
  border-radius: 16px;
  max-width: 500px;
  width: 90%;
  position: relative;
  box-shadow: 0 10px 40px rgba(0, 0, 0, 0.3);
  animation: slideUp 0.3s ease;
}

.close-button {
  position: absolute;
  top: 1rem;
  right: 1rem;
  background: none;
  border: none;
  font-size: 2rem;
  color: #666;
  cursor: pointer;
  line-height: 1;
  padding: 0;
  width: 32px;
  height: 32px;
  transition: color 0.2s ease;
}

.close-button:hover {
  color: #333;
}

.popup-title {
  font-size: 1.75rem;
  font-weight: 700;
  color: rgb(151, 187, 101);
  margin-bottom: 1.5rem;
  text-align: center;
}

.downloads-guide {
  margin-bottom: 1.5rem;
  text-align: center;
}

.downloads-guide p {
  color: #333;
  font-size: 1.1rem;
  margin-bottom: 0.75rem;
  font-weight: 500;
}

.downloads-image {
  max-width: 100%;
  height: auto;
  border-radius: 8px;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
}

.install-steps {
  text-align: left;
  color: #333;
  font-size: 1.1rem;
  line-height: 2;
  margin-bottom: 2rem;
  padding-left: 1.5rem;
}

.install-steps li {
  margin-bottom: 0.75rem;
}

.install-steps strong {
  color: rgb(151, 187, 101);
  font-weight: 600;
}

.got-it-button {
  width: 100%;
  padding: 1rem;
  font-size: 1.1rem;
  font-weight: 600;
  background: rgb(151, 187, 101);
  color: white;
  border: none;
  border-radius: 8px;
  cursor: pointer;
  transition: all 0.3s ease;
}

.got-it-button:hover {
  background: rgb(141, 177, 91);
  transform: translateY(-2px);
  box-shadow: 0 4px 15px rgba(151, 187, 101, 0.3);
}

@keyframes slideUp {
  from {
    opacity: 0;
    transform: translateY(20px);
  }
  to {
    opacity: 1;
    transform: translateY(0);
  }
}

@media (max-width: 768px) {
  .title {
    font-size: 2.5rem;
  }

  .email-form {
    flex-direction: column;
    align-items: stretch;
  }

  .email-input {
    max-width: none;
  }

  .back-button {
    top: 1rem;
    left: 1rem;
    padding: 0.5rem 1rem;
    font-size: 0.9rem;
  }

  .info-box {
    padding: 1.5rem;
  }

  .info-list {
    font-size: 1rem;
  }

  .popup-content {
    padding: 2rem;
  }

  .popup-title {
    font-size: 1.5rem;
  }

  .downloads-guide p {
    font-size: 1rem;
  }

  .install-steps {
    font-size: 1rem;
  }
}
</style>
