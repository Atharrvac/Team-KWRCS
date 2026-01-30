# Contributing to CIH App

Thank you for considering contributing to this project! Here are some guidelines to help you get started.

## 🌟 How to Contribute

### Reporting Bugs

If you find a bug, please create an issue with:
- A clear title and description
- Steps to reproduce the issue
- Expected vs actual behavior
- Screenshots (if applicable)
- Your environment details (OS, Node version, etc.)

### Suggesting Features

We welcome feature suggestions! Please create an issue with:
- A clear description of the feature
- Why it would be useful
- Any implementation ideas you have

### Pull Requests

1. **Fork the repository** and create your branch from `main`
2. **Follow the code style** - Run `npm run lint` and `npm run format`
3. **Write tests** for new features
4. **Update documentation** if needed
5. **Ensure all tests pass** - Run `npm run test`
6. **Create a pull request** with a clear description

## 📝 Code Style Guidelines

### JavaScript/React

- Use functional components and hooks
- Use arrow functions for components
- Use meaningful variable and function names
- Add JSDoc comments for complex functions
- Keep components small and focused
- Use PropTypes or TypeScript for type checking

### Commit Messages

Follow the conventional commits format:
```
type(scope): subject

body

footer
```

Types:
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting, etc.)
- `refactor`: Code refactoring
- `test`: Adding or updating tests
- `chore`: Maintenance tasks

Example:
```
feat(auth): add user login functionality

- Implement login form component
- Add JWT token handling
- Create auth context provider

Closes #123
```

## 🧪 Testing

- Write unit tests for utilities and hooks
- Write integration tests for components
- Ensure test coverage stays above 80%

## 📋 Pull Request Checklist

Before submitting a PR, ensure:
- [ ] Code follows the project style guide
- [ ] All tests pass
- [ ] New tests are added for new features
- [ ] Documentation is updated
- [ ] Commit messages follow conventions
- [ ] No console.log statements remain
- [ ] Code is properly formatted

## 🤔 Questions?

Feel free to ask questions by creating an issue or reaching out to the team.

Thank you for contributing! 🎉
