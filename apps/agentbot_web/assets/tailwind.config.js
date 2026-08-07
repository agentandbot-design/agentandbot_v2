// AgentAndBot Tailwind config
module.exports = {
  content: [
    './js/**/*.js',
    '../lib/agentbot_web/**/*.{ex,heex,eex}',
  ],
  theme: {
    extend: {
      colors: {
        primary: '#6366f1',
      }
    }
  },
  plugins: [
    require('daisyui'),
  ],
  daisyui: {
    themes: ['dark'],
    darkTheme: 'dark',
  }
}
